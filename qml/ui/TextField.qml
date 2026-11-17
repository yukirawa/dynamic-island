import QtQuick

Rectangle {
    id: control
    property alias text: input.text
    property string placeholderText: ""
    property alias echoMode: input.echoMode
    property alias font: input.font
    signal accepted()
    signal textEdited(string text)

    implicitWidth: 180
    implicitHeight: 28
    radius: 4
    color: "#1c1c1e"
    border.width: 1
    border.color: input.activeFocus ? "#0a84ff" : "#3a3a3c"
    opacity: enabled ? 1 : 0.4

    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        text: control.placeholderText
        color: "#8e8e93"
        font.pixelSize: 13
        visible: input.text === ""
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: 6
        verticalAlignment: TextInput.AlignVCenter
        color: "#f2f2f7"
        font.pixelSize: 13
        selectedTextColor: "#ffffff"
        selectionColor: "#0a84ff"
        onAccepted: control.accepted()
        onTextEdited: control.textEdited(text)
    }
    function clear() { input.text = "" }
    function selectAll() { input.selectAll() }
    Component.onCompleted: if (objectName) input.objectName = objectName + "Input"
}
