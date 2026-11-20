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
constexpr int kCachePastMonths = 2;
constexpr int kCacheFutureMonths = 6;
// A document with more occurrences than this is not kept expanded; such a
// document is expanded per query instead.
constexpr int kMaxCachedOccurrences = 2000;

QString extractMeetingLink(const KCalendarCore::Incidence::Ptr &incidence)
{
    if (const QString loc = incidence->location(); !loc.isEmpty()) {
        if (const QString m = CalendarSource::meetingLink(loc); !m.isEmpty())
            return m;
    }
    if (const QString desc = incidence->description(); !desc.isEmpty()) {
        if (const QString m = CalendarSource::meetingLink(desc); !m.isEmpty())
            return m;
    }
    if (const QUrl u = incidence->url(); u.isValid()) {
        if (const QString m = CalendarSource::meetingLink(u.toString()); !m.isEmpty())
            return m;
    }
    return {};
}

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
        out.append({incidence->summary(), it.occurrenceStartDate(), it.occurrenceEndDate(), incidence->allDay(), extractMeetingLink(incidence)});
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
    ++m_generation;
    for (QNetworkReply *reply : std::as_const(m_replies)) {
        if (reply)
            reply->abort();
    }
    m_replies.clear();
    m_pending = 0;
    m_roundFailed = false;
    m_cache->documents.clear();
    if (m_urls.isEmpty()) {
        m_retry.stop();
        m_ok = false;
        m_loaded = false;
    }
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
    const quint64 gen = m_generation;
    m_replies.clear();
    m_replies.reserve(m_urls.size());
    for (const auto &url : std::as_const(m_urls)) {
        auto *reply = m_net->get(QNetworkRequest(QUrl(url)));
        m_replies.append(reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply, url, gen] {
            reply->deleteLater();
            if (gen != m_generation)
                return;
            m_replies.removeOne(reply);
            // Never log the URL: it is a secret link.
            if (reply->error() == QNetworkReply::NoError) {
                // Parse and expand once; raw .ics bytes are discarded immediately after parsing.
                cacheDocument(url, reply->readAll());
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
    auto calendar = KCalendarCore::MemoryCalendar::Ptr::create(QTimeZone::systemTimeZone());
    KCalendarCore::ICalFormat format;
    if (format.fromRawString(calendar, doc)) {
        document.calendar = calendar;
        document.parsed = true;
        const QDateTime today = QDateTime::currentDateTime().date().startOfDay();
        document.windowStart = today.addMonths(-kCachePastMonths);
        document.windowEnd = today.addMonths(kCacheFutureMonths);
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
            entry.occ = {incidence->summary(), it.occurrenceStartDate(), it.occurrenceEndDate(), incidence->allDay(),
                         extractMeetingLink(incidence)};
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
        if (!document.usable) {
            document.entries.clear();
            document.entries.squeeze();
        }
    }
    m_cache->documents.insert(url, document);
}

QList<CalendarSource::Occurrence> CalendarSource::queryOccurrences(const QDateTime &from, const QDateTime &to) const
{
    QList<Occurrence> out;
    if (!m_cache)
        return out;
    // The raw event list compares whole days, in the time zone of the query.
    const QTimeZone tz = from.timeZone();
    const QDateTime dayStart(from.date(), QTime(0, 0, 0), tz);
    const QDateTime dayEnd(to.date(), QTime(23, 59, 59, 999), tz);
    for (auto it = m_cache->documents.constBegin(); it != m_cache->documents.constEnd(); ++it) {
        const Cache::Document &document = it.value();
        const bool covered = document.usable && from >= document.windowStart && to <= document.windowEnd;
        if (covered) {
            // The expanded occurrences are filtered instead of expanding again.
            for (const auto &entry : document.entries) {
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
        // Outside the expanded range (or for uncacheable docs), expand the already-parsed calendar.
        if (!document.calendar)
            continue; // The document could not be parsed; it has no occurrences.
        out.append(expandCalendar(document.calendar, from, to));
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
    out.reserve(occ.size());
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
