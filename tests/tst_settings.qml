import QtQuick
import QtCore
import QtTest
import "../qml"
import "../qml/ui" as UI
import "../qml/logic.js" as L

TestCase {
    id: tc
    name: "Settings"
    when: windowShown

    property string fileBase: StandardPaths.writableLocation(StandardPaths.TempLocation) + "/island-settings-test-" + Date.now()
    property int fileSeq: 0

    Component {
        id: prefsComp
        Prefs { location: tc.fileBase + ".conf" }
    }
    Component {
        id: winComp
        // Tall enough that the whole Alerts page fits without scrolling.
        SettingsWindow { page: 2; visible: true; height: 1400 }
    }
    Component {
        id: loaderHostComp
        Item {
            id: host
            property string prefsFile: ""
            property Prefs prefs: Prefs { location: host.prefsFile }
            readonly property Prefs appPrefs: prefs
            property alias loader: settingsLoader
            Loader {
                id: settingsLoader
                active: false
                sourceComponent: Component {
                    SettingsWindow {
                        prefs: host.appPrefs
                        visible: true
                        page: 0
                        onClosing: Qt.callLater(() => {
                            if (settingsLoader.item && !settingsLoader.item.visible)
                                settingsLoader.active = false
                        })
                    }
                }
            }
        }
    }

    function make(page) {
        const prefs = createTemporaryObject(prefsComp, tc, { location: tc.fileBase + "-" + (tc.fileSeq++) + ".conf" })
        prefs.history.known = JSON.stringify([{ key: "org.telegram.desktop", name: "Telegram", icon: "", kind: "apps" }])
        prefs.history.off = []
        prefs.history.apps = true
        prefs.history.save = true
        const win = createTemporaryObject(winComp, tc, { prefs: prefs, page: page !== undefined ? page : 2 })
        waitForRendering(win.contentItem)
        return { prefs, win }
    }

    function test_app_switch_edits_off_list() {
        const { prefs, win } = make()
        const box = findChild(win.contentItem, "historyApp-org.telegram.desktop")
        verify(box.checked)
        mouseClick(box)
        compare(L.toList(prefs.history.off), ["org.telegram.desktop"])
        verify(!box.checked)
        mouseClick(box)
        compare(L.toList(prefs.history.off), [])
    }

    function test_kind_off_disables_its_apps() {
        const { prefs, win } = make()
        const box = findChild(win.contentItem, "historyApp-org.telegram.desktop")
        verify(box.enabled)
        mouseClick(findChild(win.contentItem, "historyKind-apps"))
        compare(prefs.history.apps, false)
        verify(!box.enabled)
        prefs.history.apps = true
        mouseClick(findChild(win.contentItem, "historySave"))
        compare(prefs.history.save, false)
        verify(!box.enabled)
        verify(!findChild(win.contentItem, "historyKind-apps").enabled)
    }

    function test_urgent_app_switch() {
        const { prefs, win } = make()
        prefs.fullScreen.urgent = []
        prefs.fullScreen.allNotifications = false
        const box = findChild(win.contentItem, "urgentApp-org.telegram.desktop")
        verify(!box.checked)
        mouseClick(box)
        compare(L.toList(prefs.fullScreen.urgent), ["org.telegram.desktop"])
        prefs.fullScreen.allNotifications = true
        verify(!box.enabled)
    }

    function test_keep_for_days() {
        const { prefs, win } = make()
        const box = findChild(win.contentItem, "historyDays")
        compare(box.currentValue, 7)
        prefs.history.days = 30
        compare(box.currentText, "30 days")
    }

    function test_loader_binds_prefs_without_self_loop() {
        const host = createTemporaryObject(loaderHostComp, tc, { prefsFile: tc.fileBase + "-loader-" + (tc.fileSeq++) + ".conf" })
        host.loader.active = true
        const win = host.loader.item
        verify(win !== null)
        verify(win.prefs !== undefined && win.prefs !== null)
        waitForRendering(win.contentItem)

        const pill = findChild(win.contentItem, "lookPill")
        mouseClick(pill)
        compare(host.prefs.style.look, "pill")
        verify(pill.checked)
    }

    function test_radio_buttons_switch_repeatedly() {
        const { prefs, win } = make(0)
        const notch = findChild(win.contentItem, "lookNotch")
        const pill = findChild(win.contentItem, "lookPill")
        verify(notch.checked)
        verify(!pill.checked)

        mouseClick(pill)
        compare(prefs.style.look, "pill")
        verify(!notch.checked)
        verify(pill.checked)

        mouseClick(notch)
        compare(prefs.style.look, "notch")
        verify(notch.checked)
        verify(!pill.checked)

        mouseClick(pill)
        compare(prefs.style.look, "pill")
        verify(!notch.checked)
        verify(pill.checked)
    }

    function test_weather_manual_place_radio_toggles() {
        const { prefs, win } = make(5)
        const autoRadio = findChild(win.contentItem, "weatherAuto")
        const manualRadio = findChild(win.contentItem, "weatherManual")
        const cityRow = findChild(win.contentItem, "weatherCityRow")
        verify(autoRadio.checked)
        verify(!manualRadio.checked)
        verify(!cityRow.visible)

        mouseClick(manualRadio)
        verify(!autoRadio.checked)
        verify(manualRadio.checked)
        verify(cityRow.visible)

        mouseClick(autoRadio)
        verify(autoRadio.checked)
        verify(!manualRadio.checked)
        verify(!cityRow.visible)

        mouseClick(manualRadio)
        verify(manualRadio.checked)
        verify(cityRow.visible)
    }

    function test_slider_moves_and_reset_restores_controls() {
        const { prefs, win } = make(0)
        const slider = findChild(win.contentItem, "shapeHeight")
        const notch = findChild(win.contentItem, "lookNotch")
        const pill = findChild(win.contentItem, "lookPill")
        const timeBox = findChild(win.contentItem, "panelTime")
        const daysBox = findChild(win.contentItem, "historyDays")

        compare(slider.value, 32)
        mousePress(slider, slider.width * 0.5, slider.height / 2)
        mouseMove(slider, slider.width, slider.height / 2)
        mouseRelease(slider, slider.width, slider.height / 2)
        compare(prefs.shape.height, 48)
        compare(slider.value, 48)

        mouseClick(pill)
        compare(prefs.style.look, "pill")
        mouseClick(timeBox)
        compare(prefs.panel.time, false)
        verify(!timeBox.checked)

        prefs.history.days = 30
        compare(daysBox.currentValue, 30)

        win.page = 8
        waitForRendering(win.contentItem)
        const resetBtn = findChild(win.contentItem, "resetButton")
        verify(resetBtn.width > 30)
        mouseClick(resetBtn)

        compare(prefs.shape.height, 32)
        compare(slider.value, 32)
        compare(prefs.style.look, "notch")
        verify(notch.checked)
        verify(!pill.checked)
        compare(prefs.panel.time, true)
        verify(timeBox.checked)
        compare(prefs.history.days, 7)
        compare(daysBox.currentValue, 7)
        compare(daysBox.currentText, "7 days")
    }

    function test_combobox_popup_selects_and_closes_outside() {
        const { prefs, win } = make(2)
        const box = findChild(win.contentItem, "historyDays")
        verify(!box.popupVisible)

        mouseClick(box)
        verify(box.popupVisible)

        // Clicking outside the popup closes it without changing value.
        mouseClick(win.contentItem, 10, 10)
        verify(!box.popupVisible)
        compare(prefs.history.days, 7)

        // Reopen and verify wheel outside closes popup and resize repositions it.
        mouseClick(box)
        verify(box.popupVisible)
        const popup = findChild(win.contentItem, "historyDays-popup")
        verify(popup !== null)
        const oldX = popup.x
        win.width = 900
        waitForRendering(win.contentItem)
        verify(popup.x <= win.width - popup.width)
        mouseWheel(win.contentItem, 10, 10, 0, -120)
        verify(!box.popupVisible)
        compare(oldX >= 0, true)

        // Reopen and select "30 days" (index 2).
        mouseClick(box)
        verify(box.popupVisible)
        const item2 = findChild(win.contentItem, "historyDays-item-2")
        verify(item2 !== null)
        mouseClick(item2)
        verify(!box.popupVisible)
        compare(prefs.history.days, 30)
        compare(box.currentValue, 30)
        compare(box.currentText, "30 days")

        // Programmatic prefs change still updates ComboBox via binding.
        prefs.history.days = 1
        compare(box.currentValue, 1)
        compare(box.currentText, "1 day")
    }

    function test_checkbox_and_switch_toggle_both_ways() {
        const { prefs, win } = make(0)
        const timeBox = findChild(win.contentItem, "panelTime")
        verify(timeBox.checked)
        mouseClick(timeBox)
        compare(prefs.panel.time, false)
        verify(!timeBox.checked)
        mouseClick(timeBox)
        compare(prefs.panel.time, true)
        verify(timeBox.checked)

        prefs.calendar.icsUrls = ["https://example.com/cal.ics"]
        prefs.calendar.disabled = []
        win.page = 4
        waitForRendering(win.contentItem)
        const sw = findChild(win.contentItem, "calendarSwitch-0")
        verify(sw !== null)
        verify(sw.checked)
        mouseClick(sw)
        compare(L.toList(prefs.calendar.disabled), ["https://example.com/cal.ics"])
        verify(!sw.checked)
        mouseClick(sw)
        compare(L.toList(prefs.calendar.disabled), [])
        verify(sw.checked)
    }

    function test_layout_widths_visibility_and_color_popup() {
        const { prefs, win } = make(0)
        const customBtn = findChild(win.contentItem, "customColorButton")
        verify(customBtn.width > 30)

        const notch = findChild(win.contentItem, "lookNotch")
        verify(notch.implicitWidth > 0 && notch.implicitWidth !== 260)

        const popup = findChild(win.contentItem, "colorPopup")
        const colorField = findChild(win.contentItem, "colorField")
        const swatch = findChild(win.contentItem, "colorSwatch")
        verify(!popup.visible)

        mouseClick(customBtn)
        verify(popup.visible)
        keyClick(Qt.Key_Escape)
        verify(!popup.visible)

        mouseClick(customBtn)
        verify(popup.visible)
        colorField.text = "#ff00aa"
        compare(swatch.color, "#ff00aa")
        mouseClick(popup, 10, 10)
        verify(!popup.visible)
        compare(prefs.style.accent, "#0a84ff")

        mouseClick(customBtn)
        verify(popup.visible)
        colorField.text = "#112233"
        keyClick(Qt.Key_Return)
        verify(!popup.visible)
        compare(prefs.style.accent, "#112233")

        win.page = 3
        waitForRendering(win.contentItem)
        const glancesField = findChild(win.contentItem, "glancesField")
        verify(glancesField.visible)
        prefs.idle.mode = "nothing"
        verify(!glancesField.visible)

        prefs.idle.mode = "animation"
        waitForRendering(win.contentItem)
        const art = findChild(win.contentItem, "artPicker")
        const picker = findChild(win.contentItem, "filePicker")
        verify(art.visible)
        mouseClick(art)
        verify(art.popupVisible)
        mouseClick(findChild(win.contentItem, "artPicker-item-4"))
        verify(picker.visible)
        keyClick(Qt.Key_Escape)
        verify(!picker.visible)
        compare(art.currentIndex, 0)
    }

    Component {
        id: notesLikeScrollComp
        UI.ScrollView {
            width: 300
            height: 200
            Rectangle { anchors.fill: parent; color: "black" }
        }
    }

    function test_scrollview_no_phantom_overflow_for_fill_child() {
        const sv = createTemporaryObject(notesLikeScrollComp, tc)
        verify(sv !== null)
        compare(sv.contentHeight, 200)
    }
}
