import QtQuick

// Flat button drawn with Rectangle/Text instead of QtQuick.Controls.
Rectangle {
    id: control
    property string text: ""
    property bool checked: false
    property bool highlighted: false
    property bool displayIconOnly: false
    property string iconName: ""
    signal clicked()
    signal toggled()
    signal pressed()

    implicitWidth: displayIconOnly || iconName !== "" ? 30 : Math.max(56, text.length * 8 + 20)
    implicitHeight: 28
    radius: 5
    color: highlighted ? "#3a3a3c" : (area.containsMouse && enabled ? "#2c2c2e" : "transparent")
    border.width: checked ? 1 : 0
    border.color: "#0a84ff"
    opacity: enabled ? 1 : 0.4

    Row {
        anchors.centerIn: parent
        spacing: 5
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: iconName !== ""
            source: iconName
            color: "#e8e2d0"
            width: 15
            height: 15
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !displayIconOnly && text !== ""
            text: control.text
            color: "#f2f2f7"
            font.pixelSize: 13
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!enabled)
                return
            control.clicked()
            control.pressed()
            if (checkable) {
                control.checked = !control.checked
                control.toggled()
            }
        }
    }
    property bool checkable: false
}
