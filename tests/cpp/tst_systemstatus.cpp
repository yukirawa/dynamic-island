#include "systemstatus.h"

#include <QSignalSpy>
#include <QTest>

class TestSystemStatus : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testParseWpctl()
    {
        QCOMPARE(SystemStatus::parseWpctlVolume(QStringLiteral("Volume: 0.45\n")), std::make_optional(std::pair{45, false}));
        QCOMPARE(SystemStatus::parseWpctlVolume(QStringLiteral("Volume: 0.30 [MUTED]\n")), std::make_optional(std::pair{30, true}));
        QCOMPARE(SystemStatus::parseWpctlVolume(QStringLiteral("garbage")), std::nullopt);
    }

    void testParseNmcli()
    {
        QCOMPARE(SystemStatus::parseNmcliRadio(QStringLiteral("enabled\n")), true);
        QCOMPARE(SystemStatus::parseNmcliRadio(QStringLiteral("disabled\n")), false);
    }

    void testParseBluetooth()
    {
        const auto on = QStringLiteral("Controller 00:11:22:33:44:55 (public)\n\tName: laptop\n\tPowered: yes\n\tDiscoverable: no\n");
        const auto off = QStringLiteral("Controller 00:11:22:33:44:55 (public)\n\tPowered: no\n");
        QCOMPARE(SystemStatus::parseBluetoothPowered(on), true);
        QCOMPARE(SystemStatus::parseBluetoothPowered(off), false);
        QCOMPARE(SystemStatus::parseBluetoothPowered(QString()), false);
    }

    void testParseBattery()
    {
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("80\n"), QStringLiteral("Charging\n")), (std::pair{80, true}));
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("100\n"), QStringLiteral("Full\n")), (std::pair{100, true}));
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("37\n"), QStringLiteral("Discharging\n")), (std::pair{37, false}));
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("80\n"), QStringLiteral("Not charging\n")), (std::pair{80, true}));
    }

    void testSilenced()
    {
        // Plasma holds notifications while a full-screen app is active; the island can look past
        // those holds, never past do not disturb the user switched on.
        QVERIFY(SystemStatus::silenced(false, false, true, false));
        QVERIFY(!SystemStatus::silenced(false, false, true, true));
        QVERIFY(SystemStatus::silenced(false, true, false, true));
        QVERIFY(SystemStatus::silenced(true, false, false, true));
        QVERIFY(!SystemStatus::silenced(false, false, false, false));
    }

    void testDndUntil()
    {
        const QDateTime now(QDate(2026, 10, 23), QTime(15, 0));
        QCOMPARE(SystemStatus::dndUntilActive(QStringLiteral("2026-10-23T16:00:00"), now), true);
        QCOMPARE(SystemStatus::dndUntilActive(QStringLiteral("2026-10-23T14:00:00"), now), false);
        QCOMPARE(SystemStatus::dndUntilActive(QString(), now), false);
    }

    void testRefreshBatteryEmitsOnlyOnChange()
    {
        const QByteArray oldEnv = qgetenv("DYNAMIC_ISLAND_BATTERY");
        qputenv("DYNAMIC_ISLAND_BATTERY", "42");
        SystemStatus status;
        QSignalSpy spy(&status, &SystemStatus::changed);
        status.refreshBattery();
        QCOMPARE(spy.count(), 0);
        qputenv("DYNAMIC_ISLAND_BATTERY", "41");
        status.refreshBattery();
        QCOMPARE(spy.count(), 1);
        status.refreshEditMode();
        status.refreshEditMode();
        if (oldEnv.isEmpty())
            qunsetenv("DYNAMIC_ISLAND_BATTERY");
        else
            qputenv("DYNAMIC_ISLAND_BATTERY", oldEnv);
    }
};

QTEST_GUILESS_MAIN(TestSystemStatus)
#include "tst_systemstatus.moc"
