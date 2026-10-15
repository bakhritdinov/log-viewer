import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// One field of a log entry with include (+), exclude (−), show-as-column and
// copy actions.
// Desktop: key and value side by side; touch: stacked, 44 px buttons.
Control {
    id: root

    required property string key
    required property string value
    property bool touch: false
    property bool columnable: false     // offers "show as a column" (desktop) / "in the card" (touch)
    property bool isColumn: false       // already shown that way
    // Desktop: the actions show on the hovered row only, so values stay readable.
    readonly property bool actionsShown: touch || hover.hovered || root.activeFocus || root.visualFocus

    signal includeRequested()
    signal excludeRequested()
    signal copyRequested()
    signal columnToggled()

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
                Layout.alignment: Qt.AlignTop
                text: root.key
                // Long names and values wrap instead of being cut off.
                wrapMode: Text.WrapAnywhere
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                text: root.value
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 8
                elide: Text.ElideRight
                font.family: Theme.mono
                font.pixelSize: root.touch ? Theme.fontLg : Theme.fontSm
                color: Theme.textStrong
            }
        }
        IconButton {
            Layout.alignment: Qt.AlignTop
            opacity: root.actionsShown ? 1 : 0
            iconName: "plus"
            label: qsTr("Show only %1 = %2").arg(root.key).arg(root.value)
            touch: root.touch
            iconColor: root.touch ? Theme.accent : (hovered ? Theme.accent : Theme.textMuted)
            onClicked: root.includeRequested()
        }
        IconButton {
            Layout.alignment: Qt.AlignTop
            opacity: root.actionsShown ? 1 : 0
            iconName: "minus"
            label: qsTr("Exclude %1 = %2").arg(root.key).arg(root.value)
            touch: root.touch
            iconColor: hovered ? Theme.dangerText : Theme.textMuted
            onClicked: root.excludeRequested()
        }
        IconButton {
            Layout.alignment: Qt.AlignTop
            visible: root.columnable
            // Shown while it is a column, so the row tells it is one.
            opacity: root.actionsShown || root.isColumn ? 1 : 0
            iconName: "column"
            checked: root.isColumn
            label: root.isColumn ? (root.touch ? qsTr("Remove %1 from the card").arg(root.key) : qsTr("Remove the %1 column").arg(root.key))
                                 : (root.touch ? qsTr("Show %1 in the card").arg(root.key) : qsTr("Show %1 as a column").arg(root.key))
            touch: root.touch
            iconColor: root.isColumn || hovered ? Theme.accent : Theme.textMuted
            onClicked: root.columnToggled()
        }
        IconButton {
            Layout.alignment: Qt.AlignTop
            visible: !root.touch                       // touch: long-press copies
            opacity: root.actionsShown ? 1 : 0
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
