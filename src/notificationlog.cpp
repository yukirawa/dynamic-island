#include "notificationlog.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>

NotificationLog::NotificationLog(QObject *parent)
    : NotificationLog(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/dynamic-island/notifications.json"), parent)
{
}

NotificationLog::NotificationLog(const QString &file, QObject *parent)
    : QObject(parent)
    , m_file(file)
{
    QFile f(m_file);
    // A broken file reads as an empty array, and the next save replaces it. Non-object rows would throw in QML.
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonArray rows = QJsonDocument::fromJson(f.readAll()).array();
        m_items.reserve(rows.size());
        for (const QJsonValue &row : rows) {
            if (row.isObject())
                m_items.append(row.toObject().toVariantMap());
        }
    }
}

void NotificationLog::save(const QVariantList &items)
{
    m_items = items;
    // The history is small (at most a few days of rows), so writing it here is
    // cheaper and safer than a worker thread with a nested event loop: that
    // loop let QML re-enter save(), and it could deliver events for objects
    // that were already being destroyed during shutdown.
    QDir().mkpath(QFileInfo(m_file).absolutePath());
    QSaveFile f(m_file);
    // Bodies hold private messages, so only the owner may read the file.
    if (f.open(QIODevice::WriteOnly)) {
        f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        const QByteArray json = QJsonDocument(QJsonArray::fromVariantList(m_items)).toJson(QJsonDocument::Compact);
        if (f.write(json) == json.size() && f.commit())
            QFile::setPermissions(m_file, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        else
            f.cancelWriting();
    }
    Q_EMIT itemsChanged();
}
