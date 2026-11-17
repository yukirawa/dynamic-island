import QtQuick
import QtQuick.Window
import "ui" as UI
import QtCore
import Island
import "logic.js" as L

// Settings are drawn entirely with QtQuick primitives. The old Kirigami
// FormLayout + QtQuick.Controls stack loaded a theme scan, a style plugin and
// a dialog implementation before the window was ever opened.
Window {
    id: win

    required property var prefs
    property var calendar: null

    title: qsTr("Dynamic Island settings")
    width: 760
    height: 600
    minimumWidth: 620
    minimumHeight: 400
    color: "#1e1e1f"
    // The island is a layer-shell surface, which can't parent a normal window.
    transientParent: null

    readonly property var calendarUrls: L.toList(prefs.calendar.icsUrls)
    readonly property var disabledUrls: L.toList(prefs.calendar.disabled)
    readonly property var hiddenButtons: L.toList(prefs.quickButtons.hidden)
    readonly property var links: L.parseLinks(prefs.tools.links)
    readonly property var knownApps: L.parseKnownApps(prefs.history.known)
    readonly property var offApps: L.toList(prefs.history.off)
    readonly property var urgentApps: L.toList(prefs.fullScreen.urgent)

    function saveLinks(list) { prefs.tools.links = JSON.stringify(list) }
    function moved(list, from, to) {
        const out = list.slice()
        out.splice(to, 0, out.splice(from, 1)[0])
        return out
    }
    function toggled(list, item, on) {
        const rest = list.filter(x => x !== item)
        return on ? rest.concat([item]) : rest
    }

    property int page: 0
    readonly property var pages: [
            { label: qsTr("Look"), icon: "preferences-desktop-theme-global" },
            { label: qsTr("Behaviour"), icon: "preferences-system-windows-behavior" },
            { label: qsTr("Alerts"), icon: "preferences-desktop-notification" },
            { label: qsTr("When idle"), icon: "preferences-desktop-screensaver" },
            { label: qsTr("Calendar"), icon: "view-calendar" },
            { label: qsTr("Weather"), icon: "weather-few-clouds" },
            { label: qsTr("Quick buttons"), icon: "view-grid" },
            { label: qsTr("Quick links"), icon: "link" },
            { label: qsTr("General"), icon: "preferences-system" }
    ]

    Row {
        anchors.fill: parent

        ListView {
            id: sidebar
            width: 190
            height: parent.height
            model: win.pages
            clip: true
            delegate: UI.ItemDelegate {
                required property var modelData
                required property int index
                text: modelData.label
                iconName: modelData.icon
                highlighted: win.page === index
                onClicked: win.page = index
            }
        }
        Rectangle { width: 1; height: parent.height; color: "#3a3a3c" }

        Item {
            width: parent.width - 191
            height: parent.height
            clip: true

            Page { visible: win.page === 0; title: qsTr("Look"); anchors.fill: parent
                Field { label: qsTr("Style:")
                    Column {
                        spacing: 6
                        UI.RadioButton {
                            text: qsTr("Notch, joined to the top edge")
                            checked: win.prefs.style.look === "notch"
                            onToggled: win.prefs.style.look = "notch"
                        }
                        UI.RadioButton {
                            text: qsTr("Pill, floating below the edge")
                            checked: win.prefs.style.look === "pill"
                            onToggled: win.prefs.style.look = "pill"
                        }
                    }
                }
                Field { label: qsTr("Accent colour:")
                    Row {
                        spacing: 8
                        Repeater {
                            model: ["#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f", "#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#64d2ff", "#8e8e93"]
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool current: win.prefs.style.accent.toLowerCase() === modelData
                                width: 26
                                height: 26
                                radius: 13
                                color: modelData
                                border.width: current ? 3 : 0
                                border.color: "#f2f2f7"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.prefs.style.accent = parent.modelData
                                }
                            }
                        }
                        UI.Button {
                            text: qsTr("Custom…")
                            iconName: "color-picker"
                            onClicked: colorPopup.visible = true
                        }
                    }
                }
                Section { }
                SliderRow { label: qsTr("Height:"); from: 24; to: 48; suffix: qsTr(" px"); value: win.prefs.shape.height; onMoved: v => win.prefs.shape.height = v }
                SliderRow { label: qsTr("Width when empty:"); from: 100; to: 320; suffix: qsTr(" px"); value: win.prefs.shape.idleWidth; onMoved: v => win.prefs.shape.idleWidth = v }
                SliderRow { label: qsTr("Width with music or timer:"); from: 160; to: 420; suffix: qsTr(" px"); value: win.prefs.shape.compactWidth; onMoved: v => win.prefs.shape.compactWidth = v }
                SliderRow { label: qsTr("Corner roundness:"); from: 0; to: 20; suffix: qsTr(" px"); value: win.prefs.shape.radius; onMoved: v => win.prefs.shape.radius = v }
                SliderRow { label: qsTr("Curves at the top:"); enabled: win.prefs.style.look === "notch"; from: 0; to: 16; suffix: qsTr(" px"); value: win.prefs.shape.ears; onMoved: v => win.prefs.shape.ears = v }
                Section { }
                Field { label: qsTr("Top of the open panel:")
                    Row {
                        spacing: 20
                        UI.CheckBox {
                            text: qsTr("Time")
                            checked: win.prefs.panel.time
                            onToggled: win.prefs.panel.time = checked
                        }
                        UI.CheckBox {
                            text: qsTr("Date")
                            checked: win.prefs.panel.date
                            onToggled: win.prefs.panel.date = checked
                        }
                    }
                }
            }

            Page { visible: win.page === 1; title: qsTr("Behaviour"); anchors.fill: parent
                SliderRow { label: qsTr("Switch music and timer every:"); from: 3; to: 30; suffix: qsTr(" s"); value: win.prefs.behaviour.cycleSeconds; onMoved: v => win.prefs.behaviour.cycleSeconds = v }
                SliderRow { label: qsTr("After a swipe, hold for:"); from: 5; to: 60; suffix: qsTr(" s"); value: win.prefs.behaviour.swipeHoldSeconds; onMoved: v => win.prefs.behaviour.swipeHoldSeconds = v }
                SliderRow { label: qsTr("Keep paused music for:"); from: 1; to: 60; suffix: qsTr(" min"); value: win.prefs.behaviour.pausedMinutes; onMoved: v => win.prefs.behaviour.pausedMinutes = v }
                Field { label: qsTr("Open the panel:")
                    Column {
                        spacing: 6
                        UI.RadioButton {
                            text: qsTr("On click")
                            checked: !win.prefs.behaviour.openOnHover
                            onToggled: win.prefs.behaviour.openOnHover = false
                        }
                        UI.RadioButton {
                            text: qsTr("When the pointer rests on it")
                            checked: win.prefs.behaviour.openOnHover
                            onToggled: win.prefs.behaviour.openOnHover = true
                        }
                    }
                }
            }

            Page { visible: win.page === 2; title: qsTr("Alerts"); anchors.fill: parent
                Field { label: qsTr("Show:")
                    Column {
                        spacing: 4
                        Repeater {
                            model: [
                                { key: "levels", label: qsTr("Volume and brightness (hides Plasma's box)") },
                                { key: "notifications", label: qsTr("Notifications (hides Plasma's popups)") },
                                { key: "privacy", label: qsTr("Microphone and camera in use") },
                                { key: "devices", label: qsTr("Bluetooth devices connecting") },
                                { key: "meetings", label: qsTr("Join button for meetings") },
                                { key: "power", label: qsTr("Charger plugged in or out") },
                                { key: "jobs", label: qsTr("Downloads and file copies") }
                            ]
                            delegate: UI.CheckBox {
                                required property var modelData
                                text: modelData.label
                                checked: win.prefs.show[modelData.key]
                                onToggled: win.prefs.show[modelData.key] = checked
                            }
                        }
                    }
                }
                Section { }
                Field { label: qsTr("Over full-screen apps:")
                    Column {
                        spacing: 4
                        Repeater {
                            model: [
                                { key: "levels", label: qsTr("Volume and brightness") },
                                { key: "jobs", label: qsTr("Downloads and file copies") },
                                { key: "privacy", label: qsTr("Microphone and camera in use") },
                                { key: "devices", label: qsTr("Bluetooth devices connecting") },
                                { key: "power", label: qsTr("Charger plugged in or out") },
                                { key: "allNotifications", label: qsTr("Show all notifications") }
                            ]
                            delegate: UI.CheckBox {
                                required property var modelData
                                objectName: "fullScreen-" + modelData.key
                                text: modelData.label
                                checked: win.prefs.fullScreen[modelData.key]
                                onToggled: win.prefs.fullScreen[modelData.key] = checked
                            }
                        }
                    }
                }
                Field { label: qsTr("Urgent apps:")
                    Column {
                        spacing: 4
                        UI.Label {
                            visible: win.knownApps.length === 0
                            text: qsTr("Apps show up here once they send a notification.")
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.knownApps
                            delegate: Row {
                                id: urgent
                                required property var modelData
                                spacing: 6
                                UI.CheckBox {
                                    id: urgentBox
                                    objectName: "urgentApp-" + urgent.modelData.key
                                    enabled: !win.prefs.fullScreen.allNotifications
                                    checked: win.urgentApps.includes(urgent.modelData.key)
                                    onToggled: win.prefs.fullScreen.urgent = win.toggled(win.urgentApps, urgent.modelData.key, checked)
                                }
                                UI.Icon {
                                    enabled: urgentBox.enabled
                                    width: 16; height: 16
                                    source: urgent.modelData.icon || "preferences-desktop-notification"
                                    fallback: "preferences-desktop-notification"
                                }
                                UI.Label {
                                    enabled: urgentBox.enabled
                                    text: urgent.modelData.name
                                }
                            }
                        }
                    }
                }
                Section { }
                UI.CheckBox {
                    objectName: "historySave"
                    label: qsTr("History:")
                    text: qsTr("Save notifications")
                    checked: win.prefs.history.save
                    onToggled: win.prefs.history.save = checked
                }
                UI.ComboBox {
                    objectName: "historyDays"
                    label: qsTr("Keep them for:")
                    enabled: win.prefs.history.save
                    textRole: "label"
                    valueRole: "days"
                    readonly property var choices: [
                        { days: 1, label: qsTr("1 day") },
                        { days: 7, label: qsTr("7 days") },
                        { days: 30, label: qsTr("30 days") }
                    ]
                    model: choices
                    currentIndex: Math.max(0, choices.findIndex(c => c.days === win.prefs.history.days))
                    onActivated: win.prefs.history.days = currentValue
                }
                Repeater {
                    model: [
                        { key: "system", label: qsTr("System") },
                        { key: "apps", label: qsTr("Apps") },
                        { key: "others", label: qsTr("Others") }
                    ]
                    delegate: Field {
                        id: kind
                        required property var modelData
                        required property int index
                        label: index === 0 ? qsTr("Save from:") : ""
                        Column {
                            spacing: 4
                            UI.CheckBox {
                                objectName: "historyKind-" + kind.modelData.key
                                text: kind.modelData.label
                                enabled: win.prefs.history.save
                                checked: win.prefs.history[kind.modelData.key]
                                onToggled: win.prefs.history[kind.modelData.key] = checked
                            }
                            Repeater {
                                model: win.knownApps.filter(a => a.kind === kind.modelData.key)
                                delegate: Row {
                                    id: app
                                    required property var modelData
                                    spacing: 6
                                    UI.CheckBox {
                                        id: appBox
                                        objectName: "historyApp-" + app.modelData.key
                                        enabled: win.prefs.history.save && win.prefs.history[kind.modelData.key]
                                        checked: !win.offApps.includes(app.modelData.key)
                                        onToggled: win.prefs.history.off = win.toggled(win.offApps, app.modelData.key, !checked)
                                    }
                                    UI.Icon {
                                        enabled: appBox.enabled
                                        width: 16; height: 16
                                        source: app.modelData.icon || "preferences-desktop-notification"
                                        fallback: "preferences-desktop-notification"
                                    }
                                    UI.Label {
                                        enabled: appBox.enabled
                                        text: app.modelData.name
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Page { visible: win.page === 3; title: qsTr("When idle"); anchors.fill: parent
                Field { label: qsTr("Show:")
                    Column {
                        spacing: 6
                        Repeater {
                            model: [
                                { key: "glances", label: qsTr("Glances") },
                                { key: "animation", label: qsTr("My animation") },
                                { key: "nothing", label: qsTr("Nothing") }
                            ]
                            delegate: UI.RadioButton {
                                required property var modelData
                                required property int index
                                text: modelData.label
                                checked: win.prefs.idle.mode === modelData.key
                                onToggled: win.prefs.idle.mode = modelData.key
                            }
                        }
                    }
                }
                Field { label: qsTr("Glances:")
                    Column {
                        spacing: 4
                        UI.CheckBox {
                            visible: win.prefs.idle.mode === "glances"
                            text: qsTr("Events starting in 30 minutes or less")
                            checked: win.prefs.idle.events
                            onToggled: win.prefs.idle.events = checked
                        }
                        UI.CheckBox {
                            visible: win.prefs.idle.mode === "glances"
                            text: qsTr("Battery (warns at 15% or less)")
                            checked: win.prefs.idle.battery
                            onToggled: win.prefs.idle.battery = checked
                        }
                        UI.CheckBox {
                            visible: win.prefs.idle.mode === "glances"
                            text: qsTr("Time")
                            checked: win.prefs.idle.time
                            onToggled: win.prefs.idle.time = checked
                        }
                        UI.CheckBox {
                            visible: win.prefs.idle.mode === "glances"
                            text: qsTr("Weather")
                            checked: win.prefs.idle.weather
                            onToggled: win.prefs.idle.weather = checked
                        }
                        UI.CheckBox {
                            visible: win.prefs.idle.mode === "glances"
                            text: qsTr("Pending system updates")
                            checked: win.prefs.idle.updates
                            onToggled: win.prefs.idle.updates = checked
                        }
                    }
                }
                UI.ComboBox {
                    id: artPicker
                    visible: win.prefs.idle.mode === "animation"
                    label: qsTr("Animation:")
                    readonly property string current: win.prefs.idle.animation || "builtin:aurora"
                    textRole: "label"
                    valueRole: "key"
                    model: [
                        { key: "builtin:aurora", label: qsTr("Aurora") },
                        { key: "builtin:wave", label: qsTr("Wave") },
                        { key: "builtin:fireflies", label: qsTr("Fireflies") },
                        { key: "builtin:cat", label: qsTr("Cat") },
                        { key: "file", label: qsTr("My own GIF or WebP…") }
                    ]
                    currentIndex: current.startsWith("builtin:") ? Math.max(0, indexOfValue(current)) : 4
                    onActivated: {
                        if (currentValue === "file")
                            filePicker.open(qsTr("Choose an animation"), "*.gif *.webp", v => win.prefs.idle.animation = v)
                        else
                            win.prefs.idle.animation = currentValue
                    }
                }
                Field {
                    visible: win.prefs.idle.mode === "animation" && !artPicker.current.startsWith("builtin:")
                    label: qsTr("File:")
                    Row {
                        spacing: 8
                        UI.Label {
                            width: 200
                            elide: Text.ElideMiddle
                            text: decodeURIComponent(artPicker.current.split("/").pop())
                        }
                        UI.Button {
                            text: qsTr("Change…")
                            iconName: "document-open"
                            onClicked: filePicker.open(qsTr("Choose an animation"), "*.gif *.webp", v => win.prefs.idle.animation = v)
                        }
                    }
                }
                UI.Label {
                    visible: win.prefs.idle.mode === "animation"
                    text: qsTr("Point at the island to see it play.")
                    opacity: 0.7
                    font.pixelSize: 11
                }
                UI.CheckBox {
                    visible: win.prefs.idle.mode === "animation"
                    text: qsTr("Only play when the pointer is on the island")
                    checked: win.prefs.idle.animateOnHoverOnly
                    onToggled: win.prefs.idle.animateOnHoverOnly = checked
                }
            }

            Page { visible: win.page === 4; title: qsTr("Calendar"); anchors.fill: parent
                SliderRow { label: qsTr("Check for changes every:"); from: 5; to: 120; suffix: qsTr(" min"); value: win.prefs.calendar.refreshMinutes; onMoved: v => win.prefs.calendar.refreshMinutes = v }
                Field { label: qsTr("Calendars:")
                    Column {
                        spacing: 6
                        UI.Label {
                            visible: win.calendarUrls.length === 0
                            text: qsTr("None yet")
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.calendarUrls
                            delegate: Row {
                                required property string modelData
                                spacing: 8
                                UI.Switch {
                                    text: L.calendarLabel(modelData)
                                    checked: !win.disabledUrls.includes(modelData)
                                    onToggled: win.prefs.calendar.disabled = win.toggled(win.disabledUrls, modelData, !checked)
                                }
                                UI.ToolButton {
                                    iconName: "edit-delete-remove"
                                    text: qsTr("Remove")
                                    UI.ToolTip { text: parent.text; visible: parent.hovered; delay: 300 }
                                    onClicked: {
                                        win.prefs.calendar.icsUrls = win.calendarUrls.filter(u => u !== modelData)
                                        win.prefs.calendar.disabled = win.disabledUrls.filter(u => u !== modelData)
                                    }
                                }
                            }
                        }
                    }
                }
                Field { label: qsTr("Add a calendar:")
                    Row {
                        spacing: 8
                        UI.TextField {
                            id: newUrl
                            width: 240
                            echoMode: TextInput.Password
                            placeholderText: qsTr("Secret address in iCal format")
                            onAccepted: addButton.clicked()
                        }
                        UI.Button {
                            id: addButton
                            text: qsTr("Add")
                            enabled: /^https?:\/\//.test(newUrl.text.trim()) && !win.calendarUrls.includes(newUrl.text.trim())
                            onClicked: {
                                win.prefs.calendar.icsUrls = win.calendarUrls.concat([newUrl.text.trim()])
                                newUrl.clear()
                            }
                        }
                    }
                }
                UI.Label {
                    width: 400
                    text: qsTr("Google Calendar → Settings → your calendar → Integrate calendar → Secret address in iCal format.")
                    wrapMode: Text.Wrap
                    opacity: 0.7
                    font.pixelSize: 11
                }
                Row {
                    spacing: 8
                    visible: win.calendar !== null && win.calendarUrls.length > 0
                    UI.Button {
                        text: qsTr("Refresh now")
                        iconName: "view-refresh"
                        onClicked: win.calendar.refresh()
                    }
                    UI.Label {
                        opacity: 0.7
                        text: !win.calendar || !win.calendar.loaded ? ""
                            : win.calendar.ok ? qsTr("Updated %1").arg(Qt.formatTime(win.calendar.lastSuccess, "HH:mm"))
                            : qsTr("Couldn't reach the calendar")
                    }
                }
            }

            Page { visible: win.page === 5; title: qsTr("Weather"); anchors.fill: parent
                Field { label: qsTr("Location:")
                    Column {
                        spacing: 6
                        UI.RadioButton {
                            id: autoPlace
                            text: qsTr("Find automatically")
                            checked: win.prefs.weather.city === ""
                            onToggled: win.prefs.weather.city = ""
                        }
                        UI.RadioButton {
                            id: manualPlace
                            text: win.prefs.weather.city !== "" ? qsTr("Use %1").arg(win.prefs.weather.city) : qsTr("Use a city I choose")
                            checked: win.prefs.weather.city !== ""
                        }
                        Row {
                            visible: manualPlace.checked
                            spacing: 8
                            UI.TextField {
                                id: cityField
                                width: 200
                                placeholderText: qsTr("City name")
                                onAccepted: findButton.clicked()
                            }
                            UI.Button {
                                id: findButton
                                text: qsTr("Find")
                                enabled: cityField.text.trim() !== ""
                                onClicked: win.findCity(cityField.text.trim())
                            }
                        }
                        UI.Label {
                            id: cityStatus
                            visible: manualPlace.checked && text !== ""
                            opacity: 0.7
                        }
                    }
                }
                Field { label: qsTr("Temperature:")
                    Column {
                        spacing: 6
                        UI.RadioButton {
                            text: qsTr("°C")
                            checked: !win.prefs.weather.fahrenheit
                            onToggled: win.prefs.weather.fahrenheit = false
                        }
                        UI.RadioButton {
                            text: qsTr("°F")
                            checked: win.prefs.weather.fahrenheit
                            onToggled: win.prefs.weather.fahrenheit = true
                        }
                    }
                }
            }

            Page { visible: win.page === 6; title: qsTr("Quick buttons"); anchors.fill: parent
                Field { label: qsTr("Show:")
                    Column {
                        spacing: 4
                        Repeater {
                            model: [
                                { key: "battery", label: qsTr("Battery") },
                                { key: "volume", label: qsTr("Volume") },
                                { key: "wifi", label: qsTr("Wi-Fi") },
                                { key: "bluetooth", label: qsTr("Bluetooth") },
                                { key: "dnd", label: qsTr("Do not disturb") },
                                { key: "awake", label: qsTr("Keep screen awake") },
                                { key: "screenshot", label: qsTr("Screenshot") },
                                { key: "lock", label: qsTr("Lock screen") }
                            ]
                            delegate: UI.CheckBox {
                                required property var modelData
                                text: modelData.label
                                checked: !win.hiddenButtons.includes(modelData.key)
                                onToggled: win.prefs.quickButtons.hidden = win.toggled(win.hiddenButtons, modelData.key, !checked)
                            }
                        }
                    }
                }
            }

            Page { visible: win.page === 7; title: qsTr("Quick links"); anchors.fill: parent
                Field { label: qsTr("Links:")
                    Column {
                        spacing: 6
                        UI.Label {
                            visible: win.links.length === 0
                            text: qsTr("None yet")
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.links
                            delegate: Row {
                                required property var modelData
                                required property int index
                                spacing: 6
                                UI.Label {
                                    width: 220
                                    elide: Text.ElideRight
                                    text: qsTr("%1  ·  %2").arg(modelData.name || L.linkName(modelData.url)).arg(L.linkName(modelData.url))
                                }
                                UI.ToolButton {
                                    iconName: "go-up"
                                    text: qsTr("Move up")
                                    enabled: index > 0
                                    UI.ToolTip { text: parent.text; visible: parent.hovered; delay: 300 }
                                    onClicked: win.saveLinks(win.moved(win.links, index, index - 1))
                                }
                                UI.ToolButton {
                                    iconName: "edit-delete-remove"
                                    text: qsTr("Remove")
                                    UI.ToolTip { text: parent.text; visible: parent.hovered; delay: 300 }
                                    onClicked: win.saveLinks(win.links.filter((_, i) => i !== index))
                                }
                            }
                        }
                    }
                }
                Field { label: qsTr("Add a link:")
                    UI.TextField {
                        id: linkAddress
                        width: 280
                        placeholderText: qsTr("Site or folder, e.g. ~/Documents")
                        onAccepted: addLink.clicked()
                    }
                }
                Row {
                    spacing: 8
                    UI.TextField {
                        id: linkName
                        width: 200
                        placeholderText: qsTr("Name (optional)")
                        onAccepted: addLink.clicked()
                    }
                    UI.Button {
                        id: addLink
                        text: qsTr("Add")
                        iconName: "list-add"
                        enabled: linkAddress.text.trim() !== ""
                        onClicked: {
                            const url = L.linkUrl(linkAddress.text, StandardPaths.writableLocation(StandardPaths.HomeLocation).toString())
                            win.saveLinks(win.links.concat([{ name: linkName.text.trim(), url: url }]))
                            linkAddress.clear()
                            linkName.clear()
                        }
                    }
                }
                UI.Label {
                    text: qsTr("They open from the island: ⋯ → Quick links.")
                    opacity: 0.7
                    font.pixelSize: 11
                }
            }

            Page { visible: win.page === 8; title: qsTr("General"); anchors.fill: parent
                UI.Switch {
                    label: qsTr("Start at login:")
                    checked: AppConfig.autostart
                    onToggled: AppConfig.autostart = checked
                }
                UI.Button {
                    text: qsTr("Reset to defaults")
                    iconName: "edit-reset"
                    onClicked: win.prefs.reset()
                }
                UI.Label {
                    text: qsTr("Your calendars and animation file are kept.")
                    opacity: 0.7
                    font.pixelSize: 11
                }
            }
        }
    }

    function findCity(name) {
        cityStatus.text = qsTr("Looking…")
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            let hit = null
            try {
                const results = JSON.parse(xhr.responseText).results
                hit = results && results.length ? results[0] : null
            } catch (e) {}
            if (xhr.status !== 200 || !hit) {
                cityStatus.text = xhr.status === 200 ? qsTr("No city found with that name") : qsTr("Couldn't search right now")
                return
            }
            win.prefs.weather.latitude = hit.latitude
            win.prefs.weather.longitude = hit.longitude
            win.prefs.weather.city = hit.name
            cityStatus.text = qsTr("Using %1").arg(hit.name) + (hit.country ? qsTr(", %1").arg(hit.country) : "")
            cityField.clear()
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(name))
        xhr.send()
    }

    // A one-line field plus a button, instead of QtQuick.Dialogs.ColorDialog.
    Rectangle {
        id: colorPopup
        visible: false
        z: 20
        anchors.centerIn: parent
        width: 280
        height: 110
        radius: 8
        color: "#2c2c2e"
        border.width: 1
        border.color: "#48484a"
        Column {
            anchors.centerIn: parent
            spacing: 10
            UI.TextField {
                id: colorField
                width: 220
                text: win.prefs.style.accent
                placeholderText: qsTr("#rrggbb")
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                UI.Button {
                    text: qsTr("Cancel")
                    onClicked: colorPopup.visible = false
                }
                UI.Button {
                    text: qsTr("Choose")
                    onClicked: {
                        const c = colorField.text.trim()
                        if (/^#[0-9a-fA-F]{6}$/.test(c))
                            win.prefs.style.accent = c
                        colorPopup.visible = false
                    }
                }
            }
        }
    }

    // Text-based path picker, instead of QtQuick.Dialogs.FileDialog.
    Rectangle {
        id: filePicker
        visible: false
        z: 20
        anchors.centerIn: parent
        width: 360
        height: 120
        radius: 8
        color: "#2c2c2e"
        border.width: 1
        border.color: "#48484a"
        property var onChoose: null
        function open(title, filters, callback) {
            pathField.text = ""
            heading.text = title
            onChoose = callback
            visible = true
        }
        Column {
            anchors.centerIn: parent
            spacing: 10
            UI.Label { id: heading; font.pixelSize: 14 }
            UI.TextField { id: pathField; width: 320; placeholderText: "/home/me/animation.webp" }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                UI.Button { text: qsTr("Cancel"); onClicked: filePicker.visible = false }
                UI.Button {
                    text: qsTr("Open")
                    onClicked: {
                        if (pathField.text.trim() !== "" && filePicker.onChoose)
                            filePicker.onChoose("file://" + pathField.text.trim())
                        filePicker.visible = false
                    }
                }
            }
        }
    }

    component Section: Rectangle {
        width: parent ? parent.width : 400
        height: 1
        color: "#3a3a3c"
    }

    component Field: Item {
        id: field
        property string label: ""
        property int labelWidth: 190
        default property alias content: row.data
        width: parent ? parent.width : 500
        height: Math.max(26, row.childrenRect.height)
        Row {
            id: row
            width: parent.width
            spacing: 4
            Text {
                width: field.labelWidth
                text: field.label
                color: "#c7c7cc"
                font.pixelSize: 13
                wrapMode: Text.Wrap
                topPadding: 4
            }
        }
    }

    component Page: UI.ScrollView {
        id: pageView
        property string title: ""
        default property alias pageContent: column.data
        anchors.margins: 0
        Column {
            id: column
            x: 18
            y: 14
            width: pageView.availableWidth - 36
            spacing: 10
            UI.Heading {
                text: pageView.title
                level: 2
            }
        }
    }

    component SliderRow: Field {
        id: row
        property int from: 0
        property int to: 1
        property int value: 0
        property string suffix: ""
        signal moved(int v)
        Row {
            spacing: 10
            UI.Slider {
                width: 200
                from: row.from
                to: row.to
                stepSize: 1
                value: row.value
                onMoved: row.moved(Math.round(value))
            }
            UI.Label { text: row.value + row.suffix }
        }
    }
}
