import QtQuick

Item {
    id: control
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property real value: from
    signal moved(real newValue)

    implicitWidth: 200
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        width: parent.width
        height: 4
        anchors.verticalCenter: parent.verticalCenter
        radius: 2
        color: "#3a3a3c"
        Rectangle {
            width: track.fraction * parent.width
            height: parent.height
            radius: 2
            color: "#0a84ff"
        }
        Rectangle {
            x: track.fraction * parent.width - 7
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
        preventStealing: true
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: mouse => updateValue(mouse.x)
        onPositionChanged: mouse => { if (pressed) updateValue(mouse.x) }
        function updateValue(x) {
            if (!control.enabled || control.to <= control.from || control.width <= 0)
                return
            const raw = control.from + (control.to - control.from) * Math.min(1, Math.max(0, x / control.width))
            const snapped = control.stepSize > 0
                ? control.from + Math.round((raw - control.from) / control.stepSize) * control.stepSize
                : raw
            const clamped = Math.min(control.to, Math.max(control.from, snapped))
            if (clamped !== control.value)
                control.moved(clamped)
        }
    }
}
