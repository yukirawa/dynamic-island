import QtQuick

Item {
    id: control
    property string text: ""
    property string label: ""
    property bool checked: false
    signal toggled()

    implicitWidth: Math.max(box.width + 6 + (labelText.visible ? labelText.width : 0), textItem.width + box.width + 8)
    implicitHeight: 24
    enabled: true

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
        id: labelText
        visible: control.label !== ""
        anchors.right: box.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: control.label
        color: "#c7c7cc"
        font.pixelSize: 13
    }
    Text {
        id: textItem
        anchors.left: box.right
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
            if (!control.enabled)
                return
            control.checked = !control.checked
            control.toggled()
        }
    }
}
