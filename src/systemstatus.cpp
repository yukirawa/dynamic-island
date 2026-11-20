#include "systemstatus.h"

#include <QColor>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusVariant>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QHash>
#include <QPointer>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <KIdleTime>

namespace
{
const QString kSink = QStringLiteral("@DEFAULT_AUDIO_SINK@");
const QString kDefaultBattery = QStringLiteral("/sys/class/power_supply/BAT0/");
// PolicyAgent inhibition type for screen dimming/locking.
constexpr uint kChangeScreenSettings = 4;

QString readFile(const QString &path)
{
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
}

QString detectBatteryDir()
{
    const QString rootPath = QStringLiteral("/sys/class/power_supply");
    const QDir root(rootPath);
    const QStringList entries = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    QString fallback;
    for (const QString &name : entries) {
        const QString dir = rootPath + QLatin1Char('/') + name + QLatin1Char('/');
        if (!QFile::exists(dir + QStringLiteral("capacity")))
            continue;
        const QString type = readFile(dir + QStringLiteral("type")).trimmed();
        if (type != QLatin1String("Battery"))
            continue;
        const QString scope = readFile(dir + QStringLiteral("scope")).trimmed();
        if (!scope.isEmpty() && scope != QLatin1String("System"))
            continue;
        if (name == QLatin1String("BAT0"))
            return dir;
        if (fallback.isEmpty())
            fallback = dir;
    }
    return fallback.isEmpty() ? kDefaultBattery : fallback;
}

QDBusMessage notifyCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
                                          QStringLiteral("org.freedesktop.Notifications"), method);
}

QDBusMessage screenSaverCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                                          QStringLiteral("org.freedesktop.ScreenSaver"), method);
}

// Plain messages skip QDBusInterface's introspection round trip; reads never block the UI.
void callAsync(QObject *context, const QDBusMessage &msg, std::function<void(const QDBusMessage &)> done)
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        done(QDBusMessage());
        return;
    }
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(msg, 2000), context);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, context, [watcher, done] {
        done(watcher->reply());
        watcher->deleteLater();
    });
}

// The inhibition cookies arrive by callback now, so the state of a request that
// is still on its way has to be kept somewhere. The header cannot grow, so it
// lives here, next to the object it belongs to.
struct AsyncState {
    bool dndWanted = false;
    bool dndPending = false;
    bool awakeWanted = false;
    bool awakePending = false;
    bool keepAwakeHeld = false;
    bool editModePending = false;
    int idleTimeoutId = 0;
    QString batteryDir;
    bool hasBattery = false;
    bool batteryDirChecked = false;
};

QHash<const SystemStatus *, AsyncState> &asyncStates()
{
    static QHash<const SystemStatus *, AsyncState> states;
    return states;
}

AsyncState &stateFor(const SystemStatus *status)
{
    return asyncStates()[status];
}
}

SystemStatus::SystemStatus(QObject *parent)
    : QObject(parent)
{
    refresh();
    auto bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        bus.connect(QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("/org/kde/ScreenBrightness"),
                    QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("BrightnessChanged"), this,
                    SLOT(onBrightnessChanged(QString, int, QString, QString)));
    }

    const QString platform = QGuiApplication::platformName();
    if (!platform.isEmpty() && platform != QLatin1String("offscreen")) {
        if (auto *idle = KIdleTime::instance()) {
            const int id = idle->addIdleTimeout(60 * 1000);
            stateFor(this).idleTimeoutId = id;
            connect(idle, &KIdleTime::timeoutReached, this, [this, idle, id](int reachedId, int) {
                if (reachedId != id)
                    return;
                if (!m_userIdle) {
                    m_userIdle = true;
                    Q_EMIT changed();
                }
                idle->catchNextResumeEvent();
            });
            connect(idle, &KIdleTime::resumingFromIdle, this, [this] {
                if (m_userIdle) {
                    m_userIdle = false;
                    Q_EMIT changed();
                }
            });
        }
    }
}

void SystemStatus::onBrightnessChanged(const QString &display, int value, const QString &, const QString &)
{
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("/org/kde/ScreenBrightness/") + display,
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.kde.ScreenBrightness.Display") << QStringLiteral("MaxBrightness");
    // Asking for the maximum blocks the GUI thread until the daemon answers,
    // so the answer is picked up by a callback instead.
    callAsync(this, get, [this, value](const QDBusMessage &reply) {
        const QDBusVariant max = reply.arguments().isEmpty() ? QDBusVariant() : reply.arguments().first().value<QDBusVariant>();
        const int top = max.variant().toInt();
        if (top > 0)
            Q_EMIT brightnessChanged(qRound(value * 100.0 / top));
    });
}

SystemStatus::~SystemStatus()
{
    for (QProcess *proc : findChildren<QProcess *>(Qt::FindDirectChildrenOnly)) {
        proc->disconnect(this);
        if (proc->state() != QProcess::NotRunning) {
            proc->kill();
            proc->waitForFinished(100);
        }
    }
    auto bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        if (m_dndCookie)
            bus.send(notifyCall(QStringLiteral("UnInhibit")) << m_dndCookie);
        if (m_awakeCookie)
            bus.send(screenSaverCall(QStringLiteral("UnInhibit")) << m_awakeCookie);
    }
    if (const int idleId = stateFor(this).idleTimeoutId) {
        if (auto *idle = KIdleTime::instance())
            idle->removeIdleTimeout(idleId);
    }
    asyncStates().remove(this);
}

std::optional<std::pair<int, bool>> SystemStatus::parseWpctlVolume(const QString &output)
{
    static const QRegularExpression re(QStringLiteral("^Volume:\\s+([0-9.]+)(\\s+\\[MUTED\\])?"));
    const auto m = re.match(output.trimmed());
    if (!m.hasMatch())
        return std::nullopt;
    return std::pair{qRound(m.captured(1).toDouble() * 100), m.hasCaptured(2)};
}

bool SystemStatus::parseNmcliRadio(const QString &output)
{
    return output.trimmed() == QLatin1String("enabled");
}

bool SystemStatus::parseBluetoothPowered(const QString &output)
{
    static const QRegularExpression re(QStringLiteral("^\\s*Powered:\\s*yes\\s*$"), QRegularExpression::MultilineOption);
    return re.match(output).hasMatch();
}

std::pair<int, bool> SystemStatus::parseBattery(const QString &capacity, const QString &status)
{
    // Plugged in, not just "Charging": a full battery on the charger reports "Full" or "Not charging".
    return {capacity.trimmed().toInt(), status.trimmed() != QLatin1String("Discharging")};
}

bool SystemStatus::dndUntilActive(const QString &until, const QDateTime &now)
{
    const auto when = QDateTime::fromString(until.trimmed(), Qt::ISODate);
    return when.isValid() && when > now;
}

void SystemStatus::run(const QString &program, const QStringList &args, std::function<void(const QString &)> done)
{
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [proc, done] {
        if (done)
            done(QString::fromUtf8(proc->readAllStandardOutput()));
        proc->deleteLater();
    });
    connect(proc, &QProcess::errorOccurred, this, [proc](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            proc->deleteLater();
    });
    proc->start(program, args);
}

void SystemStatus::refresh()
{
    readBattery();
    readDnd();
    readKeepAwake();
    run(QStringLiteral("wpctl"), {QStringLiteral("get-volume"), kSink}, [this](const QString &out) {
        if (const auto v = parseWpctlVolume(out)) {
            m_volume = v->first;
            m_muted = v->second;
            Q_EMIT changed();
        }
    });
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi")}, [this](const QString &out) {
        m_wifi = parseNmcliRadio(out);
        Q_EMIT changed();
    });
    run(QStringLiteral("bluetoothctl"), {QStringLiteral("show")}, [this](const QString &out) {
        m_bluetooth = parseBluetoothPowered(out);
        Q_EMIT changed();
    });
}

void SystemStatus::readBattery()
{
    const int prevBattery = m_battery;
    const bool prevCharging = m_charging;
    // DYNAMIC_ISLAND_BATTERY=12 pretends the battery is at 12% and unplugged, to preview the low-battery glance.
    const QString fake = qEnvironmentVariable("DYNAMIC_ISLAND_BATTERY");
    if (!fake.isEmpty()) {
        const auto [capacity, charging] = parseBattery(fake, QStringLiteral("Discharging"));
        m_battery = capacity;
        m_charging = charging;
    } else {
        AsyncState &st = stateFor(this);
        if (!st.batteryDirChecked || (st.hasBattery && !QFile::exists(st.batteryDir + QStringLiteral("capacity")))) {
            st.batteryDir = detectBatteryDir();
            st.hasBattery = QFile::exists(st.batteryDir + QStringLiteral("capacity"));
            st.batteryDirChecked = true;
        }
        if (!st.hasBattery) {
            // No battery (a desktop): -1 keeps it out of the pill instead of reading as 0%.
            m_battery = -1;
            m_charging = false;
        } else {
            const auto [capacity, charging] =
                parseBattery(readFile(st.batteryDir + QStringLiteral("capacity")), readFile(st.batteryDir + QStringLiteral("status")));
            m_battery = capacity;
            m_charging = charging;
        }
    }
    if (m_battery != prevBattery || m_charging != prevCharging)
        Q_EMIT changed();
}

bool SystemStatus::silenced(bool ownDnd, bool trayDnd, bool inhibited, bool ignoreHolds)
{
    return ownDnd || trayDnd || (inhibited && !ignoreHolds);
}

void SystemStatus::readDnd()
{
    // Plasma's own DND (tray) lives in plasmanotifyrc; other apps' holds show up as Inhibited.
    const QSettings rc(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/plasmanotifyrc"),
                       QSettings::IniFormat);
    m_trayDnd = dndUntilActive(rc.value(QStringLiteral("DoNotDisturb/Until")).toString(), QDateTime::currentDateTime());
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.freedesktop.Notifications") << QStringLiteral("Inhibited");
    callAsync(this, get, [this](const QDBusMessage &reply) {
        m_inhibited = !reply.arguments().isEmpty() && reply.arguments().first().value<QDBusVariant>().variant().toBool();
        // The own hold counts from the moment it is asked for; the cookie only
        // arrives once the daemon has answered.
        const bool own = m_dndCookie || stateFor(this).dndPending;
        m_dnd = silenced(own, m_trayDnd, m_inhibited, false);
        Q_EMIT changed();
    });
}

void SystemStatus::refreshEditMode()
{
    AsyncState &st = stateFor(this);
    if (st.editModePending)
        return;
    st.editModePending = true;
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.kde.PlasmaShell") << QStringLiteral("editMode");
    callAsync(this, get, [this](const QDBusMessage &reply) {
        stateFor(this).editModePending = false;
        const bool on = !reply.arguments().isEmpty() && reply.arguments().first().value<QDBusVariant>().variant().toBool();
        if (on != m_editMode) {
            m_editMode = on;
            Q_EMIT changed();
        }
    });
}

void SystemStatus::readKeepAwake()
{
    auto has = QDBusMessage::createMethodCall(QStringLiteral("org.kde.Solid.PowerManagement"), QStringLiteral("/org/kde/Solid/PowerManagement/PolicyAgent"),
                                              QStringLiteral("org.kde.Solid.PowerManagement.PolicyAgent"), QStringLiteral("HasInhibition"));
    has << kChangeScreenSettings;
    callAsync(this, has, [this](const QDBusMessage &reply) {
        const bool held = !reply.arguments().isEmpty() && reply.arguments().first().toBool();
        stateFor(this).keepAwakeHeld = held;
        m_keepAwake = m_awakeCookie || held;
        Q_EMIT changed();
    });
}

void SystemStatus::toggleMute()
{
    run(QStringLiteral("wpctl"), {QStringLiteral("set-mute"), kSink, QStringLiteral("toggle")}, [this](const QString &) { refresh(); });
}

void SystemStatus::changeVolume(int deltaPercent)
{
    const auto step = QStringLiteral("%1%%2").arg(qAbs(deltaPercent)).arg(deltaPercent >= 0 ? QLatin1Char('+') : QLatin1Char('-'));
    run(QStringLiteral("wpctl"), {QStringLiteral("set-volume"), QStringLiteral("-l"), QStringLiteral("1.0"), kSink, step},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setWifi(bool on)
{
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi"), on ? QStringLiteral("on") : QStringLiteral("off")},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setBluetooth(bool on)
{
    run(QStringLiteral("bluetoothctl"), {QStringLiteral("power"), on ? QStringLiteral("on") : QStringLiteral("off")},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setDnd(bool on)
{
    AsyncState &st = stateFor(this);
    st.dndWanted = on;
    if (on && !m_dndCookie && !st.dndPending && QDBusConnection::sessionBus().isConnected()) {
        // The notification daemon hands out the hold; waiting for it would
        // freeze the window, so the cookie is picked up by a callback.
        st.dndPending = true;
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(notifyCall(QStringLiteral("Inhibit")) << QStringLiteral("dynamic-island")
                                                                                                  << QStringLiteral("Do not disturb") << QVariantMap(),
                                                                                                  2000));
        const QPointer<SystemStatus> guard(this);
        connect(watcher, &QDBusPendingCallWatcher::finished, watcher, [watcher, guard] {
            const QDBusMessage reply = watcher->reply();
            watcher->deleteLater();
            const uint cookie = reply.arguments().isEmpty() ? 0 : reply.arguments().first().toUInt();
            if (!guard) {
                // The island is gone, so nobody would give the hold back.
                if (cookie)
                    QDBusConnection::sessionBus().send(notifyCall(QStringLiteral("UnInhibit")) << cookie);
                return;
            }
            AsyncState &s = stateFor(guard);
            s.dndPending = false;
            if (!s.dndWanted) {
                // Switched off again while the daemon was thinking.
                if (cookie)
                    QDBusConnection::sessionBus().send(notifyCall(QStringLiteral("UnInhibit")) << cookie);
                return;
            }
            guard->m_dndCookie = cookie;
            guard->m_dnd = SystemStatus::silenced(guard->m_dndCookie, guard->m_trayDnd, guard->m_inhibited, false);
            Q_EMIT guard->changed();
        });
    } else if (!on) {
        if (m_dndCookie) {
            QDBusConnection::sessionBus().send(notifyCall(QStringLiteral("UnInhibit")) << m_dndCookie);
            m_dndCookie = 0;
        }
        run(QStringLiteral("kwriteconfig6"),
            {QStringLiteral("--notify"), QStringLiteral("--file"), QStringLiteral("plasmanotifyrc"), QStringLiteral("--group"),
             QStringLiteral("DoNotDisturb"), QStringLiteral("--key"), QStringLiteral("Until"), QStringLiteral("--delete")},
            [this](const QString &) { readDnd(); });
    }
    readDnd();
}

void SystemStatus::setKeepAwake(bool on)
{
    AsyncState &st = stateFor(this);
    st.awakeWanted = on;
    if (on && !m_awakeCookie && !st.awakePending && QDBusConnection::sessionBus().isConnected()) {
        // As with do not disturb, the cookie comes back by callback.
        st.awakePending = true;
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(screenSaverCall(QStringLiteral("Inhibit")) << QStringLiteral("dynamic-island")
                                                                                                  << QStringLiteral("Keep screen awake"),
                                                                                                  2000));
        const QPointer<SystemStatus> guard(this);
        connect(watcher, &QDBusPendingCallWatcher::finished, watcher, [watcher, guard] {
            const QDBusMessage reply = watcher->reply();
            watcher->deleteLater();
            const uint cookie = reply.arguments().isEmpty() ? 0 : reply.arguments().first().toUInt();
            if (!guard) {
                if (cookie)
                    QDBusConnection::sessionBus().send(screenSaverCall(QStringLiteral("UnInhibit")) << cookie);
                return;
            }
            AsyncState &s = stateFor(guard);
            s.awakePending = false;
            if (!s.awakeWanted) {
                if (cookie)
                    QDBusConnection::sessionBus().send(screenSaverCall(QStringLiteral("UnInhibit")) << cookie);
                return;
            }
            guard->m_awakeCookie = cookie;
            guard->m_keepAwake = guard->m_awakeCookie || s.keepAwakeHeld;
            Q_EMIT guard->changed();
        });
    } else if (!on && m_awakeCookie) {
        QDBusConnection::sessionBus().send(screenSaverCall(QStringLiteral("UnInhibit")) << m_awakeCookie);
        m_awakeCookie = 0;
    }
    // The power daemon updates its inhibition list asynchronously.
    QTimer::singleShot(300, this, &SystemStatus::readKeepAwake);
}

void SystemStatus::screenshot()
{
    Q_EMIT aboutToScreenshot();
    QTimer::singleShot(300, this, [] { QProcess::startDetached(QStringLiteral("spectacle"), {}); });
}

void SystemStatus::pickColor()
{
    if (!QDBusConnection::sessionBus().isConnected())
        return;
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/ColorPicker"), QStringLiteral("org.kde.kwin.ColorPicker"),
                                              QStringLiteral("pick"));
    // Waits for the user's click, so no short timeout. A short delay lets the panel close first.
    QTimer::singleShot(300, this, [this, msg] {
        auto bus = QDBusConnection::sessionBus();
        if (!bus.isConnected())
            return;
        auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(msg, 5 * 60 * 1000), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
            watcher->deleteLater();
            const QDBusMessage reply = watcher->reply();
            if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
                return;
            // Sent as a struct holding one ARGB number.
            const QDBusArgument arg = reply.arguments().first().value<QDBusArgument>();
            uint argb = 0;
            arg.beginStructure();
            arg >> argb;
            arg.endStructure();
            Q_EMIT colorPicked(QColor::fromRgba(argb).name());
        });
    });
}

void SystemStatus::lock()
{
    QProcess::startDetached(QStringLiteral("loginctl"), {QStringLiteral("lock-session")});
}
