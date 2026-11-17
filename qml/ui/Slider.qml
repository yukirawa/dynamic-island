import QtQuick

Item {
    id: control
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property real value: from
    signal moved()

    implicitWidth: 200
    implicitHeight: 24

    Rectangle {
        id: track
        width: parent.width
        height: 4
        anchors.verticalCenter: parent.verticalCenter
        radius: 2
        color: "#3a3a3c"
        Rectangle {
            width: fraction * parent.width
            height: parent.height
            radius: 2
            color: "#0a84ff"
        }
        Rectangle {
            x: fraction * parent.width - 7
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: "#ffffff"
        }
        readonly property real fraction: control.to > control.from ? Math.min(1, Math.max(0, (control.value - control.from) / (control.to - control.from))) : 0
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: updateValue(mouseX)
        onPositionChanged: if (pressed) updateValue(mouseX)
        function updateValue(x) {
            if (!control.enabled || control.to <= control.from)
                return
            const raw = control.from + (control.to - control.from) * Math.min(1, Math.max(0, x / control.width))
            const stepped = control.from + Math.round((raw - control.from) / control.stepSize) * control.stepSize
            if (stepped !== control.value) {
                control.value = stepped
                control.moved()
            }
        }
    }
}
