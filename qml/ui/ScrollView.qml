import QtQuick

// Minimal Flickable wrapper with the two properties the settings pages use.
Flickable {
    id: view
    default property alias content: holder.data
    readonly property real availableWidth: view.width
    readonly property real availableHeight: view.height
    clip: true
    flickableDirection: Flickable.VerticalFlick
    contentWidth: view.width
    contentHeight: Math.max(view.height, holder.childrenRect.y + holder.childrenRect.height)
    boundsBehavior: Flickable.StopAtBounds

    Item {
        id: holder
        width: view.width
        height: Math.max(view.height, childrenRect.y + childrenRect.height)
    }

    // Stored in a property so it is parented to view directly rather than holder.data.
    readonly property Item _scrollIndicator: Rectangle {
        parent: view
        z: 10
        anchors.right: parent.right
        anchors.rightMargin: 3
        width: 4
        radius: 2
        color: "#8e8e93"
        visible: view.contentHeight > view.height
        opacity: view.moving || view.dragging ? 0.55 : 0.25
        readonly property real trackH: Math.max(0, view.height - 4)
        readonly property real thumbH: view.contentHeight > 0
            ? Math.min(trackH, Math.max(24, (view.height / view.contentHeight) * trackH))
            : 0
        readonly property real maxScroll: Math.max(1, view.contentHeight - view.height)
        readonly property real frac: Math.min(1, Math.max(0, view.contentY / maxScroll))
        y: 2 + frac * (trackH - thumbH)
        height: thumbH
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
