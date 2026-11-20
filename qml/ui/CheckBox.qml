import QtQuick

Item {
    id: control
    property string text: ""
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: box.width + (textItem.visible ? 6 + textItem.implicitWidth : 0)
    implicitHeight: Math.max(24, textItem.visible ? textItem.implicitHeight + 4 : 24)
    enabled: true
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: box
        width: 15
        height: 15
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        radius: 3
        color: control.checked ? "#0a84ff" : "transparent"
        border.width: control.checked ? 0 : 1
        border.color: "#8e8e93"
        Icon {
            anchors.centerIn: parent
            source: "checkmark-symbolic"
            color: "#ffffff"
            width: 11
            height: 11
            visible: control.checked
        }
    }
    Text {
        id: textItem
        visible: control.text !== ""
        anchors.left: box.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: "#f2f2f7"
        font.pixelSize: 13
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!control.enabled)
                return
            control.toggled(!control.checked)
        }
    }
}
