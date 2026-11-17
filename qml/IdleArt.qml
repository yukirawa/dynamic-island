import QtQuick

// The built-in idle animations: "aurora", "wave", "fireflies" or "cat".
Item {
    id: art

    property string name
    property bool playing: false
    property real time: 0

    // The shader clock advances one step per rendered frame instead of firing on a
    // wall-clock timer: it stays aligned with what is actually on screen and costs
    // nothing on frames the compositor skips (hidden or fully occluded window).
    FrameAnimation {
        running: art.playing && art.visible && art.name !== "cat"
        onTriggered: art.time += frameTime
    }

    ShaderEffect {
        anchors.fill: parent
        visible: art.name !== "cat"
        property real time: art.time
        property size size: Qt.size(width, height)
        fragmentShader: visible ? "qrc:/shaders/" + art.name + ".frag.qsb" : ""
    }

    PixelCat {
        anchors.fill: parent
        visible: art.name === "cat"
        playing: art.playing
    }
}
