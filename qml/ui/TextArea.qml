import QtQuick

Rectangle {
    id: control
    property alias text: edit.text
    property alias wrapMode: edit.wrapMode
    property alias font: edit.font
    property alias readOnly: edit.readOnly
    property alias cursorPosition: edit.cursorPosition
    property alias length: edit.length
    property alias color: edit.color
    property alias selectionColor: edit.selectionColor
    readonly property bool focused: edit.activeFocus
    property int padding: 4
    property string placeholderText: ""
    property color placeholderTextColor: "#8e8e93"
    // Kept for call sites written for QtQuick.Controls.TextArea.
    property var background: null

    implicitWidth: 200
    implicitHeight: 120
    color: "transparent"
    border.width: 1
    border.color: "#3a3a3c"
    radius: 4

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: control.padding
        clip: true
        contentWidth: width
        contentHeight: Math.max(edit.contentHeight, height)
        Text {
            visible: edit.text === ""
            text: control.placeholderText
            color: control.placeholderTextColor
            font: control.font
        }
        TextEdit {
            id: edit
            width: parent.width
            color: "#f2f2f7"
            font.pixelSize: 13
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            selectedTextColor: "#ffffff"
            selectionColor: "#0a84ff"
        }
    }
    function selectAll() { edit.selectAll() }
    function forceActiveFocus() { edit.forceActiveFocus() }
}
