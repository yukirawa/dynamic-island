import QtQuick

// Plain tooltip: no Controls dependency. The caller sets visible/text/delay.
Rectangle {
    id: tip
    property string text: ""
    property int delay: 500
    z: 200
    visible: false
    width: Math.min(320, label.implicitWidth + 16)
    height: label.implicitHeight + 12
    radius: 5
    color: "#2c2c2e"
    border.width: 1
    border.color: "#48484a"
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 90 } }
    property bool shown: false

    Text {
        id: label
        anchors.centerIn: parent
        text: tip.text
        color: "#f2f2f7"
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    Timer {
        id: showTimer
        interval: tip.delay
        onTriggered: tip.shown = true
    }
    onVisibleChanged: {
        if (visible)
            showTimer.start()
        else {
            showTimer.stop()
            shown = false
        }
    }
}
