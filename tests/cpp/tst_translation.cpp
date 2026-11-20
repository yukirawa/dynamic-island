#include <QGuiApplication>
#include <QLibraryInfo>
#include <QLocale>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>
#include <QTranslator>

// End-to-end check of the Japanese catalog: the .qm built by lrelease is
// embedded as the i18n resource, and QML qsTr() calls are translated through
// the same QTranslator path the app uses in src/main.cpp.
class tst_translation : public QObject
{
    Q_OBJECT
private slots:
    void loadsAndTranslatesKnownStrings();
    void fallsBackToEnglishForAnUnknownKey();
};

void tst_translation::loadsAndTranslatesKnownStrings()
{
    QTranslator ja;
    QVERIFY(ja.load(QStringLiteral(":/i18n/translations/dynamic-island-ja.qm")));
    QVERIFY(!ja.isEmpty());

    // A few strings from different contexts: logic.js, AlertView, SettingsWindow.
    QCOMPARE(ja.translate("logic", "Pinned"), QString::fromUtf8("ピン留め"));
    QCOMPARE(ja.translate("logic", "in %1 min"), QString::fromUtf8("%1 分後"));
    QCOMPARE(ja.translate("logic", "%1 %2 %3"), QString::fromUtf8("%3%2日(%1)"));
    QCOMPARE(ja.translate("logic", "%1 %2"), QString::fromUtf8("%2%1日"));
    QCOMPARE(ja.translate("logic", "just now"), QString::fromUtf8("たった今"));
    QCOMPARE(ja.translate("logic", "%1 min ago"), QString::fromUtf8("%1分前"));
    QCOMPARE(ja.translate("logic", "%1 h ago"), QString::fromUtf8("%1時間前"));
    QCOMPARE(ja.translate("MonthCalendar", "%1 %2", "month and year"), QString::fromUtf8("%2年%1"));
    QCOMPARE(ja.translate("MonthCalendar", "S", "Sunday"), QString::fromUtf8("日"));
    QCOMPARE(ja.translate("MonthCalendar", "M", "Monday"), QString::fromUtf8("月"));
    QCOMPARE(ja.translate("MonthCalendar", "T", "Tuesday"), QString::fromUtf8("火"));
    QCOMPARE(ja.translate("MonthCalendar", "W", "Wednesday"), QString::fromUtf8("水"));
    QCOMPARE(ja.translate("MonthCalendar", "T", "Thursday"), QString::fromUtf8("木"));
    QCOMPARE(ja.translate("MonthCalendar", "F", "Friday"), QString::fromUtf8("金"));
    QCOMPARE(ja.translate("MonthCalendar", "S", "Saturday"), QString::fromUtf8("土"));
    QCOMPARE(ja.translate("AlertView", "Charging"), QString::fromUtf8("充電中"));
    QCOMPARE(ja.translate("SettingsWindow", "Look"), QString::fromUtf8("外観"));

    // The language the catalog declares is Japanese, not English.
    QVERIFY(ja.language().startsWith(QStringLiteral("ja")));
}

void tst_translation::fallsBackToEnglishForAnUnknownKey()
{
    QTranslator ja;
    QVERIFY(ja.load(QStringLiteral(":/i18n/translations/dynamic-island-ja.qm")));
    // A key no one translated must come back empty so the app keeps the source text.
    QVERIFY(ja.translate("logic", "this string does not exist").isEmpty());
}

QTEST_APPLESS_MAIN(tst_translation)

#include "tst_translation.moc"
