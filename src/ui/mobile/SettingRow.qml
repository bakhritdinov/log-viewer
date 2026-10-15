import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// One setting: its name and what it does, then its control — under the text
// (segments on the full width) or, for a switch, at the right; a switch row
// toggles when tapped anywhere.
AbstractButton {
    id: root

    property string title
    property string hint
    // A switch at the right instead of a control below.
    property bool isSwitch: false
    // The value shown (bound to a preference); a tap emits switched(), the owner stores it.
    property bool switchChecked: false
    default property alias control: below.data

    signal switched(bool checked)

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 20
    Accessible.role: isSwitch ? Accessible.CheckBox : Accessible.Grouping
    Accessible.name: title
    Accessible.checked: isSwitch && switchChecked
    enabled: true
    onClicked: if (isSwitch) root.switched(!switchChecked)
    background: Rectangle { color: root.isSwitch && root.pressed ? Theme.subtle : "transparent"; radius: Theme.radiusMd }

    contentItem: ColumnLayout {
        id: column
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    wrapMode: Text.Wrap
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontLg + 1
                    font.weight: Font.Medium
                    color: Theme.textStrong
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.hint !== ""
                    text: root.hint
                    wrapMode: Text.Wrap
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
            AppSwitch {
                id: toggle
                visible: root.isSwitch
                touch: true
                Accessible.ignored: true
                checked: root.switchChecked
                // The switch flips itself; it follows the stored value again after.
                onToggled: { root.switched(checked); checked = Qt.binding(() => root.switchChecked) }
            }
        }
        ColumnLayout {
            id: below
            Layout.fillWidth: true
            visible: children.length > 0
            spacing: 8
        }
    }
}
