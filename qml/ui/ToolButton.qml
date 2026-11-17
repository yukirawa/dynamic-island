import QtQuick

Item {
    id: control
    property string text: ""
    property string iconName: ""
    property bool iconOnly: true
    property alias hovered: area.containsMouse
    signal clicked()

    implicitWidth: 26
    implicitHeight: 24

    Icon {
        anchors.centerIn: parent
        source: iconName
        color: "#f2f2f7"
        width: 15
        height: 15
        opacity: control.enabled ? 1 : 0.4
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (control.enabled) control.clicked()
    }
}
