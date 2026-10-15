pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// A long press on a field: filter by it or copy it. A filter goes back to the
// feed and searches (filtered()).
BottomSheet {
    id: root

    signal notice(string text, string actionText, var action)
    signal filtered()

    property string key
    property string value
    function openFor(k, v) { key = k; value = v; open() }

    title: key + " = " + value

    ActionRow {
        text: qsTr("Show only this value"); iconName: "plus"; tint: Theme.accentText
        onClicked: { Session.toggleFilter(root.key, root.value, false); root.close(); root.filtered() }
    }
    ActionRow {
        text: qsTr("Exclude this value"); iconName: "minus"; tint: Theme.dangerText
        onClicked: { Session.toggleFilter(root.key, root.value, true); root.close(); root.filtered() }
    }
    // A line under the message in every card (the desktop's column).
    ActionRow {
        readonly property bool shown: Session.prefs.extraColumns.indexOf(root.key) >= 0
        text: shown ? qsTr("Remove from the card") : qsTr("Show in the card"); iconName: "column"
        onClicked: {
            if (shown) Session.prefs.removeColumn(root.key); else Session.prefs.addColumn(root.key)
            root.close()
        }
    }
    ActionRow {
        text: qsTr("Copy the value"); iconName: "copy"
        onClicked: { clipboard.copy(root.value); root.close(); root.notice(qsTr("Copied"), "", null) }
    }
    ActionRow {
        text: qsTr("Copy as %1").arg(root.key + ":\"" + root.value + "\""); iconName: "copy"
        onClicked: { clipboard.copy(root.key + ":\"" + root.value + "\""); root.close(); root.notice(qsTr("Copied"), "", null) }
    }
    Item { implicitHeight: 12 }

    Clipboard { id: clipboard }

    component ActionRow: AbstractButton {
        id: action
        property string iconName
        property color tint: Theme.textMuted
        Layout.fillWidth: true
        implicitHeight: 48
        Accessible.name: text
        background: Rectangle { color: action.pressed ? Theme.subtle : "transparent" }
        contentItem: RowLayout {
            spacing: 14
            Icon { Layout.leftMargin: 18; name: action.iconName; size: 18; color: action.tint }
            Text {
                Layout.fillWidth: true
                text: action.text
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg + 1
                color: Theme.textStrong
            }
        }
    }
}
