import QtQuick

Text {
    property int level: 2
    color: "#f2f2f7"
    font.pixelSize: level === 1 ? 24 : (level === 2 ? 19 : 15)
    font.weight: Font.DemiBold
}
