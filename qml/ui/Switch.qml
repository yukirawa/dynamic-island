import QtQuick

Item {
    id: control
    property string text: ""
    property string label: ""
    property bool checked: false
    signal toggled()

    implicitWidth: 240
    implicitHeight: 24

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
        id: labelText
        visible: control.label !== ""
        anchors.right: track.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: control.label
        color: "#c7c7cc"
        font.pixelSize: 13
    }
    Text {
        anchors.left: track.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: "#f2f2f7"
        font.pixelSize: 13
        opacity: control.enabled ? 1 : 0.4
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!control.enabled)
                return
            control.checked = !control.checked
            control.toggled()
        }
    }
}
