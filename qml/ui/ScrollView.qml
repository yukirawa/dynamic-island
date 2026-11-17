import QtQuick

// Minimal Flickable wrapper with the two properties the settings pages use.
Flickable {
    id: view
    default property alias content: holder.data
    readonly property real availableWidth: view.width
    readonly property real availableHeight: view.height
    clip: true
    contentWidth: Math.max(view.width, holder.childrenRect.width)
    contentHeight: Math.max(view.height, holder.childrenRect.height)
    boundsBehavior: Flickable.StopAtBounds

    Item {
        id: holder
        width: view.width
        height: Math.max(view.height, childrenRect.height)
    }
}
