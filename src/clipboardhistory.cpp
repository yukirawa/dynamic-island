#include "clipboardhistory.h"

#include <KSystemClipboard>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QMimeData>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QUuid>

namespace
{
// A burst of copies writes only the last state.
constexpr int kSaveDelayMs = 200;
// Skip oversized text blobs so multi-megabyte copies don't bloat RAM or JSON.
constexpr qsizetype kMaxTextLength = 256 * 1024;

class ClipboardWriter;

QHash<const ClipboardHistory *, ClipboardWriter *> &clipboardWriters()
{
    static QHash<const ClipboardHistory *, ClipboardWriter *> writers;
    return writers;
}

ClipboardWriter *writerFor(const ClipboardHistory *history)
{
    return clipboardWriters().value(history, nullptr);
}

// The hash of the pixels of a copied image, and its PNG file.
QString hashAndSaveImage(const QImage &source, const QString &dir)
{
    const QImage image = source.convertToFormat(QImage::Format_ARGB32);
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(QByteArrayView(image.constBits(), image.sizeInBytes()), QCryptographicHash::Sha1).toHex());
    const QString file = dir + QLatin1Char('/') + hash + QStringLiteral(".png");
    if (!QFile::exists(file) && !image.save(file, "PNG"))
        return QString();
    QFile::setPermissions(file, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return hash;
}

// The history file, written atomically with owner-only permissions.
void writeHistory(const QString &path, const QVariantList &items)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    const QByteArray json = QJsonDocument(QJsonArray::fromVariantList(items)).toJson(QJsonDocument::Compact);
    if (file.write(json) != json.size() || !file.commit()) {
        file.cancelWriting();
        return;
    }
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

// Debounces bursts of copies. The file is small, so the write itself happens
// on the GUI thread: a worker with a nested event loop made save() re-entrant
// and left queued jobs running while the app was being destroyed.
class ClipboardWriter : public QObject
{
public:
    ClipboardWriter(const ClipboardHistory *owner, const QString &dir, QObject *parent)
        : QObject(parent)
        , m_owner(owner)
        , m_dir(dir)
    {
        m_timer.setSingleShot(true);
        m_timer.setInterval(kSaveDelayMs);
        connect(&m_timer, &QTimer::timeout, this, &ClipboardWriter::writePending);
    }

    ~ClipboardWriter() override
    {
        // The last state has to reach the disk before the app goes away.
        flush();
        clipboardWriters().remove(m_owner);
    }

    void requestSave(const QVariantList &items)
    {
        m_pending = items;
        m_hasPending = true;
        m_dirty = true;
        m_timer.start();
    }

    QString hashImage(const QImage &image)
    {
        return hashAndSaveImage(image, m_dir);
    }

private:
    void flush()
    {
        if (!m_hasPending)
            return;
        m_hasPending = false;
        m_dirty = false;
        m_timer.stop();
        writeHistory(m_dir + QStringLiteral("/history.json"), m_pending);
        m_pending.clear();
        m_pending.squeeze();
    }

    void writePending()
    {
        if (!m_dirty)
            return;
        m_hasPending = false;
        m_dirty = false;
        writeHistory(m_dir + QStringLiteral("/history.json"), m_pending);
        m_pending.clear();
        m_pending.squeeze();
    }

    QTimer m_timer;
    const ClipboardHistory *m_owner;
    QString m_dir;
    QVariantList m_pending;
    bool m_hasPending = false;
    bool m_dirty = false;
};
}

ClipboardHistory::ClipboardHistory(QObject *parent)
    : ClipboardHistory(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/dynamic-island/clipboard"), true, parent)
{
}

ClipboardHistory::ClipboardHistory(const QString &directory, bool watchSystem, QObject *parent)
    : QObject(parent)
    , m_dir(directory)
    , m_watch(watchSystem)
{
    QDir().mkpath(m_dir);
    QFile::setPermissions(m_dir, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    clipboardWriters().insert(this, new ClipboardWriter(this, m_dir, this));
    load();
    if (m_watch) {
        // KSystemClipboard uses the Wayland data-control protocol, so it sees copies made while the island isn't focused.
        if (auto *clip = KSystemClipboard::instance()) {
            connect(clip, &KSystemClipboard::changed, this, [this, clip](QClipboard::Mode mode) {
                if (mode == QClipboard::Clipboard)
                    handleMime(clip->mimeData(QClipboard::Clipboard));
            });
        }
    }
}

void ClipboardHistory::handleMime(const QMimeData *mime)
{
    if (!mime || mime->data(QStringLiteral("x-kde-passwordManagerHint")) == "secret")
        return;

    const QString text = mime->text().trimmed();
    if (!text.isEmpty()) {
        if (text.size() > kMaxTextLength)
            return;
        static const QRegularExpression link(QStringLiteral("^https?://\\S+$"));
        QVariantMap item;
        item[QStringLiteral("kind")] = link.match(text).hasMatch() ? QStringLiteral("link") : QStringLiteral("text");
        item[QStringLiteral("text")] = text;
        prepend(item, QStringLiteral("text"), text);
        return;
    }

    QImage image = qvariant_cast<QImage>(mime->imageData());
    if (image.isNull() && mime->hasFormat(QStringLiteral("image/png")))
        image = QImage::fromData(mime->data(QStringLiteral("image/png")));
    auto *writer = writerFor(this);
    if (image.isNull() || !writer)
        return;
    const QString hash = writer->hashImage(image);
    if (hash.isEmpty())
        return;
    const int existing = [&] {
        for (int i = 0; i < m_items.size(); ++i)
            if (m_items.at(i).toMap().value(QStringLiteral("hash")) == hash)
                return i;
        return -1;
    }();
    QVariantMap item;
    if (existing >= 0) {
        item = m_items.at(existing).toMap();
    } else {
        const QString file = m_dir + QLatin1Char('/') + hash + QStringLiteral(".png");
        item[QStringLiteral("kind")] = QStringLiteral("image");
        item[QStringLiteral("image")] = QUrl::fromLocalFile(file).toString();
        item[QStringLiteral("width")] = image.width();
        item[QStringLiteral("height")] = image.height();
    }
    item[QStringLiteral("hash")] = hash;
    prepend(item, QStringLiteral("hash"), hash);
}

int ClipboardHistory::indexOf(const QString &id) const
{
    for (int i = 0; i < m_items.size(); ++i)
        if (m_items.at(i).toMap().value(QStringLiteral("id")).toString() == id)
            return i;
    return -1;
}

void ClipboardHistory::prepend(QVariantMap item, const QString &matchKey, const QString &matchValue)
{
    // The clipboard reports its current content again at startup; that isn't a new copy.
    if (!m_items.isEmpty() && m_items.first().toMap().value(matchKey).toString() == matchValue)
        return;
    bool pinned = false;
    QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    for (int i = 0; i < m_items.size(); ++i) {
        const QVariantMap old = m_items.at(i).toMap();
        if (old.value(matchKey).toString() == matchValue) {
            pinned = old.value(QStringLiteral("pinned")).toBool();
            id = old.value(QStringLiteral("id")).toString();
            m_items.removeAt(i);
            break;
        }
    }
    item[QStringLiteral("id")] = id;
    item[QStringLiteral("pinned")] = pinned;
    item[QStringLiteral("time")] = QDateTime::currentMSecsSinceEpoch();
    m_items.prepend(item);

    int unpinned = 0;
    for (int i = 0; i < m_items.size();) {
        const QVariantMap it = m_items.at(i).toMap();
        if (!it.value(QStringLiteral("pinned")).toBool() && ++unpinned > kMaxUnpinned) {
            dropFiles(it);
            m_items.removeAt(i);
        } else {
            ++i;
        }
    }
    save();
}

void ClipboardHistory::copy(const QString &id)
{
    const int i = indexOf(id);
    if (i < 0 || !m_watch)
        return;
    auto *clip = KSystemClipboard::instance();
    if (!clip)
        return;
    const QVariantMap item = m_items.at(i).toMap();
    auto *mime = new QMimeData;
    if (item.value(QStringLiteral("kind")) == QLatin1String("image"))
        mime->setImageData(QImage(QUrl(item.value(QStringLiteral("image")).toString()).toLocalFile()));
    else
        mime->setText(item.value(QStringLiteral("text")).toString());
    // The change comes back through handleMime, which moves the item to the top.
    clip->setMimeData(mime, QClipboard::Clipboard);
}

void ClipboardHistory::copyText(const QString &text)
{
    auto *clip = KSystemClipboard::instance();
    if (!clip)
        return;
    auto *mime = new QMimeData;
    mime->setText(text);
    clip->setMimeData(mime, QClipboard::Clipboard);
}

void ClipboardHistory::pin(const QString &id, bool on)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    QVariantMap item = m_items.at(i).toMap();
    item[QStringLiteral("pinned")] = on;
    m_items[i] = item;
    save();
}

void ClipboardHistory::remove(const QString &id)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    dropFiles(m_items.at(i).toMap());
    m_items.removeAt(i);
    save();
}

void ClipboardHistory::clear()
{
    for (int i = m_items.size() - 1; i >= 0; --i) {
        const QVariantMap item = m_items.at(i).toMap();
        if (!item.value(QStringLiteral("pinned")).toBool()) {
            dropFiles(item);
            m_items.removeAt(i);
        }
    }
    save();
}

void ClipboardHistory::dropFiles(const QVariantMap &item)
{
    if (item.contains(QStringLiteral("image")))
        QFile::remove(QUrl(item.value(QStringLiteral("image")).toString()).toLocalFile());
}

void ClipboardHistory::load()
{
    QFile file(m_dir + QStringLiteral("/history.json"));
    if (file.open(QIODevice::ReadOnly))
        m_items = QJsonDocument::fromJson(file.readAll()).array().toVariantList();
}

void ClipboardHistory::save()
{
    // A burst of copies writes only the last state.
    if (auto *writer = writerFor(this))
        writer->requestSave(m_items);
    Q_EMIT itemsChanged();
}
