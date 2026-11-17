import QtQuick

Item {
    id: control
    property string text: ""
    property string label: ""
    property bool checked: false
    signal toggled()

    implicitWidth: 260
    implicitHeight: 24

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
        id: labelText
        visible: control.label !== ""
        anchors.right: dot.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: control.label
        color: "#c7c7cc"
        font.pixelSize: 13
    }
    Text {
        anchors.left: dot.right
        anchors.leftMargin: 6
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
            if (!control.enabled || control.checked)
                return
            control.checked = true
            control.toggled()
        }
    }
}
