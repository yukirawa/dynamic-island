#include "capslockwatcher.h"

#include <QDir>
#include <QFile>

#include <cstdlib>

namespace
{
const QString kLedsRoot = QStringLiteral("/sys/class/leds");
constexpr int kEmptyRescanIntervalTicks = 20; // 5 s at 250 ms polling

QStringList discoverPaths(const QString &ledRoot)
{
    const QDir root(ledRoot);
    const QStringList entries = root.entryList({QStringLiteral("*capslock")}, QDir::Dirs | QDir::NoDotAndDotDot);
    QStringList paths;
    paths.reserve(entries.size());
    for (const QString &led : entries)
        paths.append(root.filePath(led + QStringLiteral("/brightness")));
    return paths;
}

bool readBrightness(const QString &path, bool *ok = nullptr)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        if (ok)
            *ok = false;
        return false;
    }
    char buf[16];
    const qint64 n = f.read(buf, sizeof(buf) - 1);
    if (ok)
        *ok = true;
    if (n <= 0)
        return false;
    buf[n] = '\0';
    return std::atoi(buf) > 0;
}
}

CapsLockWatcher::CapsLockWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(250);
    connect(&m_timer, &QTimer::timeout, this, &CapsLockWatcher::poll);
}

void CapsLockWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (on) {
        m_scanned = false;
        m_rescanTick = 0;
        m_timer.start();
        poll();
    } else {
        m_timer.stop();
        if (m_on) {
            m_on = false;
            Q_EMIT onChanged();
        }
    }
    Q_EMIT enabledChanged();
}

void CapsLockWatcher::rescan()
{
    m_brightnessPaths = discoverPaths(kLedsRoot);
    m_scanned = true;
}

void CapsLockWatcher::poll()
{
    if (!m_scanned) {
        rescan();
    } else if (m_brightnessPaths.isEmpty() && ++m_rescanTick >= kEmptyRescanIntervalTicks) {
        m_rescanTick = 0;
        rescan();
    }

    bool now = false;
    bool missing = false;
    for (const QString &path : std::as_const(m_brightnessPaths)) {
        bool ok = false;
        if (readBrightness(path, &ok)) {
            now = true;
            break;
        }
        if (!ok)
            missing = true;
    }
    if (!now && missing) {
        rescan();
        for (const QString &path : std::as_const(m_brightnessPaths)) {
            if (readBrightness(path)) {
                now = true;
                break;
            }
        }
    }

    if (now != m_on) {
        m_on = now;
        Q_EMIT onChanged();
    }
}

bool CapsLockWatcher::read(const QString &ledRoot)
{
    const QStringList paths = discoverPaths(ledRoot);
    for (const QString &path : paths) {
        if (readBrightness(path))
            return true;
    }
    return false;
}
