import QtQuick

// "ERROR" / "WARN" … badge; empty level renders nothing.
Rectangle {
    id: root

    required property string level
    property bool touch: false

    visible: level !== ""
    implicitWidth: label.implicitWidth + 16
    implicitHeight: touch ? 24 : 20
    radius: Theme.radiusSm
    color: Theme.levelSoft(level)
    border.width: 1
    border.color: Theme.tint(Theme.levelColor(level), 0.5)
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Level %1").arg(level)

    Text {
        id: label
        anchors.centerIn: parent
        text: root.level
        font.family: Theme.sans
        font.pixelSize: Theme.fontXs
        font.weight: Font.DemiBold
        color: Theme.levelTextColor(root.level)
    }
}
