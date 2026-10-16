pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// One field of a log entry with include (+), exclude (−), show-as-column and
// copy actions.
// Desktop: key and value side by side, the value uses the full width; the
// actions appear over its right end while the row is hovered or focused.
// Touch: stacked, 44 px buttons always shown.
Control {
    id: root

    required property string key
    required property string value
    property bool touch: false
    property bool columnable: false     // offers "show as a column" (desktop) / "in the card" (touch)
    property bool isColumn: false       // already shown that way
    // Hover is tracked on the whole row (not its background), so moving onto
    // an action does not hide the actions.
    readonly property bool actionsShown: touch || rowHover.hovered || root.activeFocus || root.visualFocus

    signal includeRequested()
    signal excludeRequested()
    signal copyRequested()
    signal columnToggled()

    padding: touch ? 4 : 2
    leftPadding: touch ? 12 : 6
    rightPadding: touch ? 4 : 6
    implicitHeight: Math.max(touch ? 52 : 30, contentItem.implicitHeight + topPadding + bottomPadding)
    Accessible.role: Accessible.ListItem
    Accessible.name: qsTr("%1: %2").arg(key).arg(value)

    HoverHandler { id: rowHover }

    background: Rectangle {
        id: rowBackground
        radius: Theme.radiusMd
        color: root.touch ? Theme.surface : (rowHover.hovered ? Theme.subtle : "transparent")
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
                topPadding: root.touch ? 0 : 5
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
                topPadding: root.touch ? 0 : 5
                bottomPadding: root.touch ? 0 : 5
                text: root.value
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 8
                elide: Text.ElideRight
                font.family: Theme.mono
                font.pixelSize: root.touch ? Theme.fontLg : Theme.fontSm
                color: Theme.textStrong
            }
        }
        // Desktop: only the column mark keeps a place, so the value is not
        // squeezed by actions that are hidden most of the time.
        Item {
            visible: !root.touch && root.columnable && root.isColumn
            Layout.alignment: Qt.AlignTop
            implicitWidth: 28
            implicitHeight: 28
            Icon {
                anchors.centerIn: parent
                visible: !root.actionsShown
                name: "column"
                size: 14
                color: Theme.accent
            }
        }
        // Touch: the actions in the row.
        Loader {
            active: root.touch
            visible: active
            Layout.alignment: Qt.AlignTop
            sourceComponent: actionsComponent
        }
    }

    // Desktop: the actions over the value's right end, on the row's colour
    // with a short fade so the text under them does not look cut.
    Item {
        id: overlay
        // An opaque cover over the value (contentItem is stacked above the
        // row's other children otherwise); keyboard focus without hover uses
        // the panel's colour.
        readonly property color cover: rowHover.hovered ? Theme.subtle : Theme.surface
        z: 2
        visible: !root.touch && root.actionsShown
        anchors.right: parent.right
        anchors.rightMargin: root.rightPadding
        anchors.top: parent.top
        anchors.topMargin: root.topPadding
        width: desktopActions.implicitWidth + fade.width
        height: desktopActions.implicitHeight
        Rectangle {
            id: fade
            width: 16
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: overlay.cover }
            }
        }
        Rectangle {
            x: fade.width
            width: desktopActions.implicitWidth
            height: parent.height
            radius: Theme.radiusMd
            color: overlay.cover
        }
        // Created on first hover / focus: a panel of fields rebuilt on every ↓
        // would otherwise make four buttons per row that are rarely seen.
        Loader {
            id: desktopActions
            x: fade.width
            active: !root.touch && root.actionsShown
            sourceComponent: actionsComponent
        }
    }

    Component {
        id: actionsComponent
        Row {
            spacing: root.touch ? 4 : 0
            IconButton {
                implicitWidth: root.touch ? Theme.touchHeight : 28
                implicitHeight: implicitWidth
                iconName: "plus"
                label: qsTr("Show only %1 = %2").arg(root.key).arg(root.value)
                touch: root.touch
                iconColor: root.touch ? Theme.accent : (hovered ? Theme.accent : Theme.textMuted)
                onClicked: root.includeRequested()
            }
            IconButton {
                implicitWidth: root.touch ? Theme.touchHeight : 28
                implicitHeight: implicitWidth
                iconName: "minus"
                label: qsTr("Exclude %1 = %2").arg(root.key).arg(root.value)
                touch: root.touch
                iconColor: hovered ? Theme.dangerText : Theme.textMuted
                onClicked: root.excludeRequested()
            }
            IconButton {
                visible: root.columnable
                implicitWidth: root.touch ? Theme.touchHeight : 28
                implicitHeight: implicitWidth
                iconName: "column"
                checked: root.isColumn
                label: root.isColumn ? (root.touch ? qsTr("Remove %1 from the card").arg(root.key) : qsTr("Remove the %1 column").arg(root.key))
                                     : (root.touch ? qsTr("Show %1 in the card").arg(root.key) : qsTr("Show %1 as a column").arg(root.key))
                touch: root.touch
                iconColor: root.isColumn || hovered ? Theme.accent : Theme.textMuted
                onClicked: root.columnToggled()
            }
            IconButton {
                visible: !root.touch                       // touch: long-press copies
                implicitWidth: 28
                implicitHeight: 28
                iconName: "copy"
                label: qsTr("Copy value")
                onClicked: root.copyRequested()
            }
        }
    }

    TapHandler {
        enabled: root.touch
        onLongPressed: root.copyRequested()
    }
}
