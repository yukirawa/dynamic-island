import QtQuick

Rectangle {
    id: control
    property var model: []
    property string label: ""
    property string textRole: "text"
    property string valueRole: "value"
    property int currentIndex: 0
    property alias popupVisible: popup.visible
    readonly property var currentValue: currentIndex >= 0 && currentIndex < model.length ? model[currentIndex][valueRole] : undefined
    readonly property string currentText: currentIndex >= 0 && currentIndex < model.length ? String(model[currentIndex][textRole] || "") : ""
    signal activated(int index)

    implicitWidth: 150
    implicitHeight: 28
    radius: 4
    color: "#1c1c1e"
    border.width: 1
    border.color: popup.visible ? "#0a84ff" : "#3a3a3c"
    opacity: enabled ? 1 : 0.4

    Text {
        anchors.right: parent.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: control.label
        color: "#c7c7cc"
        font.pixelSize: 13
        visible: control.label !== ""
    }
    Text {
        anchors.left: parent.left
        anchors.right: arrow.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 6
        text: control.currentText
        color: "#f2f2f7"
        font.pixelSize: 13
        elide: Text.ElideRight
    }
    Text {
        id: arrow
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "▾"
        color: "#8e8e93"
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (control.enabled)
                popup.visible = !popup.visible
        }
    }
    Rectangle {
        id: popup
        visible: false
        z: 100
        width: Math.max(control.width, 160)
        height: Math.min(model.length * 28 + 4, 220)
        y: control.height
        color: "#2c2c2e"
        border.width: 1
        border.color: "#48484a"
        radius: 4
        clip: true
        ListView {
            anchors.fill: parent
            anchors.margins: 2
            model: control.model
            delegate: Rectangle {
                width: ListView.view.width
                height: 28
                color: index === control.currentIndex ? "#0a84ff" : (ma.containsMouse ? "#3a3a3c" : "transparent")
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[control.textRole] || ""
                    color: "#f2f2f7"
                    font.pixelSize: 13
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        control.currentIndex = index
                        popup.visible = false
                        control.activated(index)
                    }
                }
            }
        }
    }
    function indexOfValue(v) {
        for (let i = 0; i < model.length; ++i)
            if (model[i][valueRole] === v)
                return i
        return -1
    }
}
