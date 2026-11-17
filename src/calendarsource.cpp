#include "calendarsource.h"

#include <KCalendarCore/Event>
#include <KCalendarCore/ICalFormat>
#include <KCalendarCore/Incidence>
#include <KCalendarCore/MemoryCalendar>
#include <KCalendarCore/OccurrenceIterator>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QTimeZone>
#include <algorithm>

namespace
{
constexpr int kRefreshMs = 15 * 60 * 1000;
constexpr int kRetryMs = 60 * 1000;
// Opening the panel re-downloads after this, so a just-added event shows up.
constexpr int kOpenStaleMs = 60 * 1000;
constexpr int kTransferTimeoutMs = 30 * 1000;
// How much of a calendar is kept expanded in memory. A query outside of it
// expands the document again, but it never parses it again.
constexpr int kCachePastYears = 1;
constexpr int kCacheFutureYears = 2;
// A document with more occurrences than this is not kept expanded; such a
// document is expanded per query instead.
constexpr int kMaxCachedOccurrences = 5000;

// The occurrences of one calendar between from and to, in the order the
// iterator hands them out.
QList<CalendarSource::Occurrence> expandCalendar(const KCalendarCore::MemoryCalendar::Ptr &calendar, const QDateTime &from, const QDateTime &to)
{
    QList<CalendarSource::Occurrence> out;
    KCalendarCore::OccurrenceIterator it(*calendar, from, to);
    while (it.hasNext()) {
        it.next();
        const auto incidence = it.incidence();
        if (incidence->type() != KCalendarCore::IncidenceBase::TypeEvent || incidence->status() == KCalendarCore::Incidence::StatusCanceled)
            continue;
        const QString link = CalendarSource::meetingLink(incidence->location() + QLatin1Char(' ') + incidence->description() + QLatin1Char(' ')
                                                         + incidence->url().toString());
        out.append({incidence->summary(), it.occurrenceStartDate(), it.occurrenceEndDate(), incidence->allDay(), link});
    }
    return out;
}
}

// One downloaded document: the parsed calendar and the occurrences it expands
// to, so that a query only has to filter them.
struct CalendarSource::Cache {
    struct Entry {
        Occurrence occ;
        // The slot of a recurring event; invalid for a one-off event.
        QDateTime slot;
        // The start and end of a one-off event, as the raw event list sees them.
        QDateTime eventStart;
        QDateTime eventEnd;
        bool plain = false;
        bool exception = false;
    };
    struct Document {
        QByteArray doc;
        KCalendarCore::MemoryCalendar::Ptr calendar;
        QList<Entry> entries;
        // The range the occurrences were expanded for.
        QDateTime windowStart;
        QDateTime windowEnd;
        // False when the document could not be parsed.
        bool parsed = false;
        // False when the document is too big to keep expanded, or has the rare
        // "this and future" exceptions; those are expanded per query.
        bool usable = true;
    };
    QHash<QString, Document> documents;
};

CalendarSource::CalendarSource(QObject *parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
    , m_cache(std::make_unique<Cache>())
{
    m_net->setTransferTimeout(kTransferTimeoutMs);
    // One quick retry after a failed round (e.g. Wi-Fi still connecting after login).
    m_retry.setSingleShot(true);
    m_retry.setInterval(kRetryMs);
    connect(&m_retry, &QTimer::timeout, this, &CalendarSource::refresh);
    m_timer.setInterval(kRefreshMs);
    connect(&m_timer, &QTimer::timeout, this, &CalendarSource::refresh);
    m_timer.start();
}

CalendarSource::~CalendarSource() = default;

QList<CalendarSource::Occurrence> CalendarSource::expand(const QList<QByteArray> &icsDocs, const QDateTime &from, const QDateTime &to)
{
    QList<Occurrence> out;
    for (const auto &doc : icsDocs) {
        auto calendar = KCalendarCore::MemoryCalendar::Ptr::create(QTimeZone::systemTimeZone());
        KCalendarCore::ICalFormat format;
        if (!format.fromRawString(calendar, doc))
            continue;
        out.append(expandCalendar(calendar, from, to));
    }
    std::sort(out.begin(), out.end(), [](const Occurrence &a, const Occurrence &b) {
        return a.start < b.start;
    });
    return out;
}

QList<CalendarSource::Occurrence> CalendarSource::upcoming(const QList<QByteArray> &icsDocs, const QDateTime &now, int count)
{
    auto occ = expand(icsDocs, now.date().startOfDay(), now.date().addDays(2).startOfDay());
    occ.erase(std::remove_if(occ.begin(), occ.end(),
                             [&now](const Occurrence &o) {
                                 // All-day events end at 00:00 of their last day; they last until the next midnight.
                                 const auto end = o.allDay ? o.end.date().addDays(1).startOfDay() : o.end;
                                 return end <= now;
                             }),
              occ.end());
    return occ.mid(0, count);
}

void CalendarSource::setRefreshMinutes(int minutes)
{
    if (minutes < 1 || minutes == refreshMinutes())
        return;
    m_timer.start(minutes * 60000);
    Q_EMIT changed();
}

void CalendarSource::setTransferTimeout(int ms)
{
    m_net->setTransferTimeout(ms);
}

void CalendarSource::setUrls(const QStringList &urls)
{
    if (urls == m_urls)
        return;
    m_urls = urls;
    m_docs.clear();
    m_cache->documents.clear();
    Q_EMIT changed();
    refresh();
}

void CalendarSource::refresh()
{
    if (m_urls.isEmpty() || m_pending > 0)
        return;
    m_lastAttempt = QDateTime::currentDateTime();
    m_pending = m_urls.size();
    m_roundFailed = false;
    for (const auto &url : std::as_const(m_urls)) {
        auto *reply = m_net->get(QNetworkRequest(QUrl(url)));
        connect(reply, &QNetworkReply::finished, this, [this, reply, url] {
            reply->deleteLater();
            // Never log the URL: it is a secret link.
            if (reply->error() == QNetworkReply::NoError) {
                m_docs.insert(url, reply->readAll());
                // The document is parsed and expanded once; the queries filter it.
                cacheDocument(url, m_docs.value(url));
            } else {
                m_roundFailed = true;
            }
            if (--m_pending > 0)
                return;
            m_ok = !m_roundFailed;
            m_loaded = true;
            if (m_ok)
                m_lastSuccess = QDateTime::currentDateTime();
            else if (!m_retry.isActive())
                m_retry.start();
            Q_EMIT changed();
        });
    }
}

void CalendarSource::refreshIfStale()
{
    if (!m_ok || !m_lastAttempt.isValid() || m_lastAttempt.msecsTo(QDateTime::currentDateTime()) >= kOpenStaleMs)
        refresh();
}

void CalendarSource::cacheDocument(const QString &url, const QByteArray &doc)
{
    Cache::Document document;
    document.doc = doc;
    auto calendar = KCalendarCore::MemoryCalendar::Ptr::create(QTimeZone::systemTimeZone());
    KCalendarCore::ICalFormat format;
    if (format.fromRawString(calendar, doc)) {
        document.calendar = calendar;
        document.parsed = true;
        const QDateTime today = QDateTime::currentDateTime().date().startOfDay();
        document.windowStart = today.addYears(-kCachePastYears);
        document.windowEnd = today.addYears(kCacheFutureYears);
        KCalendarCore::OccurrenceIterator it(*calendar, document.windowStart, document.windowEnd);
        while (it.hasNext()) {
            it.next();
            const auto incidence = it.incidence();
            if (!incidence || incidence->type() != KCalendarCore::IncidenceBase::TypeEvent
                || incidence->status() == KCalendarCore::Incidence::StatusCanceled)
                continue;
            if (incidence->thisAndFuture()) {
                // Rare: the iterator moves those differently, so they are expanded per query.
                document.usable = false;
                break;
            }
            Cache::Entry entry;
            entry.occ = {incidence->summary(),
                         it.occurrenceStartDate(),
                         it.occurrenceEndDate(),
                         incidence->allDay(),
                         meetingLink(incidence->location() + QLatin1Char(' ') + incidence->description() + QLatin1Char(' ') + incidence->url().toString())};
            entry.slot = it.recurrenceId();
            entry.exception = incidence->hasRecurrenceId();
            if (!entry.exception && !incidence->recurs()) {
                // A one-off event: the raw event list only hands it out when it reaches into the range.
                entry.plain = true;
                const auto event = incidence.staticCast<KCalendarCore::Event>();
                entry.eventStart = event->dtStart();
                entry.eventEnd = event->dtEnd();
            }
            document.entries.append(entry);
            if (document.entries.size() > kMaxCachedOccurrences) {
                document.usable = false;
                break;
            }
        }
    }
    m_cache->documents.insert(url, document);
}

QList<CalendarSource::Occurrence> CalendarSource::queryOccurrences(const QDateTime &from, const QDateTime &to) const
{
    QList<Occurrence> out;
    // The raw event list compares whole days, in the time zone of the query.
    const QTimeZone tz = from.timeZone();
    const QDateTime dayStart(from.date(), QTime(0, 0, 0), tz);
    const QDateTime dayEnd(to.date(), QTime(23, 59, 59, 999), tz);
    for (auto it = m_docs.constBegin(); it != m_docs.constEnd(); ++it) {
        const Cache::Document *document = nullptr;
        if (m_cache) {
            const auto found = m_cache->documents.constFind(it.key());
            if (found != m_cache->documents.constEnd())
                document = &*found;
        }
        const bool covered = document && document->usable && from >= document->windowStart && to <= document->windowEnd;
        if (covered) {
            // The expanded occurrences are filtered instead of expanding again.
            for (const auto &entry : document->entries) {
                if (entry.plain) {
                    // A one-off event: the raw event list only hands it out when it reaches into the range.
                    if (dayEnd.isValid() && dayEnd < entry.eventStart)
                        continue;
                    if (dayStart.isValid() && entry.eventEnd < dayStart)
                        continue;
                } else if (entry.slot < from || entry.slot > to) {
                    // A slot of a recurring event. An exception takes the place of its slot.
                    continue;
                }
                out.append(entry.occ);
            }
            continue;
        }
        // Outside the expanded range the document is expanded again, but it is never parsed again.
        KCalendarCore::MemoryCalendar::Ptr calendar = document ? document->calendar : nullptr;
        if (!calendar) {
            if (document)
                continue; // The document could not be parsed; it has no occurrences.
            calendar = KCalendarCore::MemoryCalendar::Ptr::create(QTimeZone::systemTimeZone());
            KCalendarCore::ICalFormat format;
            if (!format.fromRawString(calendar, it.value()))
                continue;
        }
        out.append(expandCalendar(calendar, from, to));
    }
    std::sort(out.begin(), out.end(), [](const Occurrence &a, const Occurrence &b) {
        return a.start < b.start;
    });
    return out;
}

QString CalendarSource::meetingLink(const QString &text)
{
    static const QRegularExpression re(QStringLiteral("https://(?:meet\\.google\\.com/|[\\w.-]*zoom\\.us/j/|teams\\.microsoft\\.com/l/meetup-join/)[^\\s<>\"]+"));
    return re.match(text).captured();
}

QVariantList CalendarSource::toVariant(const QList<Occurrence> &occ) const
{
    QVariantList out;
    for (const auto &o : occ) {
        out.append(QVariantMap{
            {QStringLiteral("title"), o.title},
            {QStringLiteral("start"), o.start},
            {QStringLiteral("end"), o.end},
            {QStringLiteral("allDay"), o.allDay},
            {QStringLiteral("link"), o.link},
        });
    }
    return out;
}

QVariantList CalendarSource::occurrences(QDate from, QDate to) const
{
    return toVariant(queryOccurrences(from.startOfDay(), to.addDays(1).startOfDay()));
}

QVariantList CalendarSource::upNext(int count) const
{
    const auto now = QDateTime::currentDateTime();
    auto occ = queryOccurrences(now.date().startOfDay(), now.date().addDays(2).startOfDay());
    occ.erase(std::remove_if(occ.begin(), occ.end(),
                             [&now](const Occurrence &o) {
                                 // All-day events end at 00:00 of their last day; they last until the next midnight.
                                 const auto end = o.allDay ? o.end.date().addDays(1).startOfDay() : o.end;
                                 return end <= now;
                             }),
              occ.end());
    return toVariant(occ.mid(0, count));
}
