import QtQuick

Item {
    id: control
    property string text: ""
    property bool checked: false
    signal toggled()

    implicitWidth: dot.width + (textItem.visible ? 6 + textItem.implicitWidth : 0)
    implicitHeight: Math.max(24, textItem.visible ? textItem.implicitHeight + 4 : 24)
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: dot
        width: 15
        height: 15
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        radius: 8
        color: "transparent"
        border.width: control.checked ? 5 : 1
        border.color: control.checked ? "#0a84ff" : "#8e8e93"
    }
    Text {
        id: textItem
        visible: control.text !== ""
        anchors.left: dot.right
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
            if (!control.enabled || control.checked)
                return
            control.toggled()
        }
    }
}
