import QtQuick
import QtQuick.Layouts

// Centered message with optional actions (first launch, nothing found).
ColumnLayout {
    id: root

    property string iconName: "logs"
    property string title
    property string message
    property bool touch: false
    default property alias actions: actionRow.data

    spacing: 12

    Icon {
        name: root.iconName
        size: 36
        strokeWidth: 1.6
        color: Theme.accent
    }
    Text {
        Layout.fillWidth: true
        text: root.title
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: root.touch ? Theme.fontHero : Theme.fontTitle
        font.weight: Font.DemiBold
        color: Theme.textStrong
        Accessible.role: Accessible.Heading
    }
    Text {
        Layout.fillWidth: true
        visible: root.message !== ""
        text: root.message
        wrapMode: Text.Wrap
        lineHeight: 1.2
        font.family: Theme.sans
        font.pixelSize: root.touch ? Theme.fontLg : Theme.fontMd
        color: Theme.textMuted
    }
    Flow {
        id: actionRow
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
    }
}
