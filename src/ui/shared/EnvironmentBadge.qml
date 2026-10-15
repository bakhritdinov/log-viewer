import QtQuick

// Environment name with its colour (PROD red, DEV green …) so production is
// never mistaken for a test system.
Rectangle {
    id: root

    required property string name
    required property color tint
    property bool touch: false
    property bool showDot: true

    implicitWidth: row.implicitWidth + 16
    implicitHeight: touch ? 28 : 24
    radius: Theme.radiusMd
    color: Theme.tint(tint, 0.14)
    border.width: 1
    border.color: Theme.tint(tint, 0.6)
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Environment %1").arg(name)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
            visible: root.showDot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: root.tint
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.name
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            font.weight: Font.DemiBold
            color: Theme.textStrong
        }
    }
}
