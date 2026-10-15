import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// One field of a log entry with include (+), exclude (−) and copy actions.
// Desktop: key and value side by side; touch: stacked, 44 px buttons.
Control {
    id: root

    required property string key
    required property string value
    property bool touch: false

    signal includeRequested()
    signal excludeRequested()
    signal copyRequested()

    padding: touch ? 4 : 2
    leftPadding: touch ? 12 : 6
    implicitHeight: Math.max(touch ? 52 : 30, contentItem.implicitHeight + topPadding + bottomPadding)
    Accessible.role: Accessible.ListItem
    Accessible.name: qsTr("%1: %2").arg(key).arg(value)

    background: Rectangle {
        radius: Theme.radiusMd
        color: root.touch ? Theme.surface : (hover.hovered ? Theme.subtle : "transparent")
        HoverHandler { id: hover }
    }

    contentItem: RowLayout {
        spacing: 4
        GridLayout {
            Layout.fillWidth: true
            columns: root.touch ? 1 : 2
            columnSpacing: 8
            rowSpacing: 2
            Text {
                Layout.preferredWidth: root.touch ? -1 : 112
                Layout.fillWidth: root.touch
                text: root.key
                elide: Text.ElideRight
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            Text {
                Layout.fillWidth: true
                text: root.value
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Theme.mono
                font.pixelSize: root.touch ? Theme.fontLg : Theme.fontSm
                color: Theme.textStrong
            }
        }
        IconButton {
            iconName: "plus"
            label: qsTr("Show only %1 = %2").arg(root.key).arg(root.value)
            touch: root.touch
            iconColor: root.touch ? Theme.accent : (hovered ? Theme.accent : Theme.textMuted)
            onClicked: root.includeRequested()
        }
        IconButton {
            iconName: "minus"
            label: qsTr("Exclude %1 = %2").arg(root.key).arg(root.value)
            touch: root.touch
            iconColor: hovered ? Theme.dangerText : Theme.textMuted
            onClicked: root.excludeRequested()
        }
        IconButton {
            visible: !root.touch                       // touch: long-press copies
            iconName: "copy"
            label: qsTr("Copy value")
            onClicked: root.copyRequested()
        }
    }

    TapHandler {
        enabled: root.touch
        onLongPressed: root.copyRequested()
    }
}
