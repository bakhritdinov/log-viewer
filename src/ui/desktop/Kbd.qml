import QtQuick

// A key cap in hints ("F5", "⌘K").
Rectangle {
    property alias text: label.text

    // Whole pixels: key caps in a column must share their edges exactly.
    implicitWidth: Math.ceil(label.implicitWidth) + 10
    implicitHeight: Math.ceil(label.implicitHeight) + 4
    radius: Theme.radiusSm
    color: "transparent"
    border.width: 1
    border.color: Theme.border
    Accessible.ignored: true

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.mono
        font.pixelSize: Theme.fontXs
        font.weight: Font.Medium
        color: Theme.textMuted
    }
}
