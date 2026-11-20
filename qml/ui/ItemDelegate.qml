import QtQuick

Rectangle {
    id: delegate
    property string text: ""
    property string iconName: ""
    property bool highlighted: false
    signal clicked()

    width: ListView.view ? ListView.view.width : 190
    height: 34
    color: highlighted ? "#0a84ff" : (area.containsMouse ? "#2c2c2e" : "transparent")
    radius: 4

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            source: delegate.iconName
            color: highlighted ? "#ffffff" : "#c7c7cc"
            width: 16
            height: 16
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: delegate.text
            color: highlighted ? "#ffffff" : "#f2f2f7"
            font.pixelSize: 13
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: delegate.clicked()
    }
}
