import QtQuick
import "ui" as Kirigami

// What the closed pill shows for a moment: a volume or brightness level, a notification, a device, the charger, a picked colour, or a finished job.
Item {
    id: view

    property var alert: null
    property bool shown: false
    // Keeps the last alert on screen while the pill fades back.
    property var a: ({ kind: "" })
    onAlertChanged: if (alert) a = alert

    readonly property real preferredWidth:
        a.kind === "color" ? colorAlert.implicitWidth + 32
        : a.kind === "power" ? powerAlert.implicitWidth + 32
        : a.kind === "capslock" ? capsLockAlert.implicitWidth + 32
        : a.kind === "privacy" ? privacyAlert.implicitWidth + 32
        : 0

    anchors.fill: parent
    visible: opacity > 0
    state: shown ? "shown" : "hidden"
    states: [
        State {
            name: "shown"
            PropertyChanges { view.opacity: 1 }
        },
        State {
            name: "hidden"
            PropertyChanges { view.opacity: 0 }
        }
    ]
    transitions: [
        Transition {
            from: "hidden"; to: "shown"
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                NumberAnimation { target: view; property: "opacity"; duration: 180; easing.type: Easing.OutCubic }
            }
        },
        Transition {
            from: "shown"; to: "hidden"
            NumberAnimation { target: view; property: "opacity"; duration: 100; easing.type: Easing.OutCubic }
        }
    ]

    Row {
        visible: view.a.kind === "volume" || view.a.kind === "brightness"
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: view.a.kind === "brightness" ? "brightness-high-symbolic"
                  : view.a.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
            color: "#ffffff"
            isMask: true
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 16 - levelText.width - 2 * parent.spacing
            height: 6
            radius: 3
            color: "#262626"
            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, (view.a.value || 0) / 100))
                height: parent.height
                radius: 3
                color: view.a.muted ? "#5a616a" : "#ffffff"
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
        Text {
            id: levelText
            objectName: "alertLevelText"
            width: 28
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(view.a.value || 0)
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    Item {
        objectName: "jobAlert"
        visible: view.a.kind === "job"
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        Kirigami.Icon {
            id: jobIcon
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: view.a.ok ? "emblem-success" : "emblem-error"
            color: view.a.ok ? "#30d158" : "#ff6b6b"
            isMask: true
        }
        Column {
            anchors.left: jobIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                objectName: "jobAlertTitle"
                width: parent.width
                text: view.a.title || ""
                color: view.a.ok ? "#ffffff" : "#ff8a8a"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                objectName: "jobAlertBody"
                width: parent.width
                text: view.a.body || ""
                color: "#9aa3ad"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    Item {
        visible: view.a.kind === "notification"
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 12
        Kirigami.Icon {
            id: appIcon
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            source: view.a.icon || "preferences-desktop-notification-symbolic"
            fallback: "preferences-desktop-notification-symbolic"
        }
        Column {
            anchors.left: appIcon.right
            anchors.leftMargin: 12
            anchors.right: nowText.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                objectName: "alertTitle"
                width: parent.width
                text: view.a.title || ""
                color: "#ffffff"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: view.a.body || ""
                color: "#9aa3ad"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        Text {
            id: nowText
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 2
            text: qsTr("now")
            color: "#9aa3ad"
            font.pixelSize: 12
        }
    }

    Row {
        id: colorAlert
        objectName: "colorAlert"
        visible: view.a.kind === "color"
        anchors.centerIn: parent
        spacing: 9
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: view.a.kind === "color" ? view.a.value : "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.25)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: view.a.kind === "color" ? String(view.a.value).toUpperCase() : ""
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Copied")
            color: "#9aa3ad"
            font.pixelSize: 12
        }
    }

    Row {
        id: powerAlert
        objectName: "powerAlert"
        visible: view.a.kind === "power"
        anchors.centerIn: parent
        spacing: 8
        readonly property string level: String(Math.round((view.a.value || 0) / 20) * 20).padStart(3, "0")
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: "battery-" + parent.level + (view.a.plugged ? "-charging" : "")
            color: view.a.plugged ? "#4ade80" : "#ffffff"
            isMask: true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(view.a.value || 0) + "%"
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !view.a.plugged ? qsTr("On battery") : view.a.value >= 100 ? qsTr("Plugged in, full") : qsTr("Charging")
            color: "#9aa3ad"
            font.pixelSize: 12
        }
    }

    Row {
        id: capsLockAlert
        objectName: "capsLockAlert"
        visible: view.a.kind === "capslock"
        anchors.centerIn: parent
        spacing: 8
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: view.a.on ? "caps-on" : "caps-off"
            fallback: "input-keyboard-symbolic"
            color: view.a.on ? "#ff9f0a" : "#ffffff"
            isMask: true
        }
        Text {
            objectName: "capsLockAlertText"
            anchors.verticalCenter: parent.verticalCenter
            text: view.a.on ? qsTr("Caps Lock on") : qsTr("Caps Lock off")
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    Row {
        id: privacyAlert
        objectName: "privacyAlert"
        visible: view.a.kind === "privacy"
        anchors.centerIn: parent
        spacing: 8
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: view.a.device === "camera" ? "camera-web-symbolic" : "audio-input-microphone-symbolic"
            color: "#ff9f0a"
            isMask: true
        }
        Text {
            objectName: "privacyAlertApp"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 140)
            text: view.a.app || ""
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            objectName: "privacyAlertText"
            anchors.verticalCenter: parent.verticalCenter
            text: view.a.device === "camera" ? qsTr("is using the camera") : qsTr("is using the microphone")
            color: "#9aa3ad"
            font.pixelSize: 12
        }
    }

    Item {
        visible: view.a.kind === "device"
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 6
        readonly property bool on: !!view.a.connected

        Rectangle {
            id: deviceCircle
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 22
            color: parent.on ? "#0b2a52" : "#141414"
            border.color: parent.on ? "#2a5c99" : "#2a2a2a"
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: (view.a.icon || "preferences-system-bluetooth") + "-symbolic"
                fallback: "preferences-system-bluetooth"
                color: deviceCircle.parent.on ? "#5aa9ff" : "#6b7280"
                isMask: true
            }
        }
        Column {
            anchors.left: deviceCircle.right
            anchors.leftMargin: 12
            anchors.right: badge.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                objectName: "deviceName"
                width: parent.width
                text: view.a.name || ""
                color: deviceCircle.parent.on ? "#ffffff" : "#9aa3ad"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Rectangle {
                readonly property bool low: view.a.battery >= 0 && view.a.battery <= 15
                visible: view.a.battery >= 0
                width: chipRow.implicitWidth + 16
                height: 22
                radius: 11
                color: "#161616"
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 8
                        radius: 2
                        color: "transparent"
                        border.color: chipRow.parent.low ? "#ff6b6b" : "#8a929c"
                        Rectangle {
                            x: 1.5
                            y: 1.5
                            width: Math.max(1, (parent.width - 3) * Math.max(0, view.a.battery) / 100)
                            height: parent.height - 3
                            radius: 1
                            color: chipRow.parent.low ? "#ff6b6b" : "#ffffff"
                        }
                    }
                    Text {
                        objectName: "deviceBattery"
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.a.battery + "%"
                        color: chipRow.parent.low ? "#ff8a8a" : "#ffffff"
                        font.pixelSize: 12
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
        Rectangle {
            id: badge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            color: parent.on ? "#30d158" : "#2a2a2a"
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 12
                height: 12
                source: badge.parent.on ? "checkmark-symbolic" : "window-close-symbolic"
                color: badge.parent.on ? "#000000" : "#9aa3ad"
                isMask: true
            }
        }
    }
}
