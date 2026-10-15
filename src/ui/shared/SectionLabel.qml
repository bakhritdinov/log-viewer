import QtQuick

// Small caps heading above a group ("FIELDS · 14").
Text {
    font.family: Theme.sans
    font.pixelSize: Theme.fontXs
    font.weight: Font.DemiBold
    font.letterSpacing: 0.6
    font.capitalization: Font.AllUppercase
    color: Theme.textMuted
    Accessible.role: Accessible.Heading
}
