import QtQuick

Item {
    id: control
    property string text: ""
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: track.width + (textItem.visible ? 8 + textItem.implicitWidth : 0)
    implicitHeight: Math.max(24, textItem.visible ? textItem.implicitHeight + 4 : 24)
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        width: 34
        height: 19
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        radius: 10
        color: control.checked ? "#0a84ff" : "#39393d"
        Rectangle {
            width: 15
            height: 15
            radius: 8
            x: control.checked ? 17 : 2
            y: 2
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 100 } }
        }
    }
    Text {
        id: textItem
        visible: control.text !== ""
        anchors.left: track.right
        anchors.leftMargin: 8
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
