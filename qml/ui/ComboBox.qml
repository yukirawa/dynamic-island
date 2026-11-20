import QtQuick
import QtQuick.Window

Rectangle {
    id: control
    property var model: []
    property string textRole: "text"
    property string valueRole: "value"
    property int currentIndex: 0
    property alias popupVisible: overlay.visible
    readonly property var currentValue: valueAt(currentIndex)
    readonly property string currentText: String(textAt(currentIndex) || "")
    signal activated(int index)

    implicitWidth: 160
    implicitHeight: 28
    radius: 4
    color: "#1c1c1e"
    border.width: 1
    border.color: overlay.visible ? "#0a84ff" : "#3a3a3c"
    opacity: enabled ? 1 : 0.4

    onVisibleChanged: if (!visible) overlay.visible = false
    onEnabledChanged: if (!enabled) overlay.visible = false

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: arrow.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
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
            if (!control.enabled)
                return
            if (overlay.visible)
                overlay.visible = false
            else if (control.model && control.model.length > 0)
                overlay.visible = true
        }
    }

    Item {
        id: overlay
        parent: control.Window.contentItem ? control.Window.contentItem : control
        anchors.fill: parent
        visible: false
        z: 1000
        focus: visible
        Keys.onEscapePressed: overlay.visible = false
        onVisibleChanged: {
            if (visible) {
                control.positionPopup()
                overlay.forceActiveFocus()
            }
        }
        onWidthChanged: if (visible) control.positionPopup()
        onHeightChanged: if (visible) control.positionPopup()

        MouseArea {
            anchors.fill: parent
            onClicked: overlay.visible = false
            onWheel: wheel => {
                overlay.visible = false
                wheel.accepted = true
            }
        }

        Rectangle {
            id: popup
            objectName: control.objectName ? control.objectName + "-popup" : ""
            width: Math.max(control.width, 200)
            height: Math.min((control.model ? control.model.length : 0) * 28 + 4, 220)
            color: "#2c2c2e"
            border.width: 1
            border.color: "#48484a"
            radius: 4
            clip: true

            // Absorb clicks and wheel events on popup chrome so they do not hit the outside catcher.
            MouseArea {
                anchors.fill: parent
                onWheel: wheel => { wheel.accepted = true }
            }

            ListView {
                id: popupList
                anchors.fill: parent
                anchors.margins: 2
                model: control.model
                delegate: Rectangle {
                    id: option
                    required property var modelData
                    required property int index
                    objectName: control.objectName ? control.objectName + "-item-" + option.index : ""
                    width: ListView.view.width
                    height: 28
                    color: option.index === control.currentIndex ? "#0a84ff" : (ma.containsMouse ? "#3a3a3c" : "transparent")
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData[control.textRole] || ""
                        color: "#f2f2f7"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            overlay.visible = false
                            control.activated(option.index)
                        }
                    }
                }
            }
        }
    }

    function positionPopup() {
        if (!overlay.parent)
            return
        const pt = control.mapToItem(overlay, 0, control.height)
        const h = popup.height
        const above = pt.y + h > overlay.height && pt.y - control.height >= h
        popup.x = Math.max(4, Math.min(pt.x, overlay.width - popup.width - 4))
        popup.y = Math.max(4, above ? (pt.y - control.height - h) : pt.y)
    }

    function valueAt(i) {
        return model && i >= 0 && i < model.length ? model[i][valueRole] : undefined
    }

    function textAt(i) {
        return model && i >= 0 && i < model.length ? model[i][textRole] : ""
    }

    function indexOfValue(v) {
        if (!model)
            return -1
        for (let i = 0; i < model.length; ++i)
            if (model[i][valueRole] === v)
                return i
        return -1
    }
}
