import QtQuick
import QtQuick.Controls.Basic

// Icon-only button. `label` is required: it is the accessible name and the tooltip.
Button {
    id: control

    property string iconName
    required property string label
    property string shortcut               // shown in the tooltip
    property bool touch: false
    property bool showTooltip: !touch
    property color iconColor: control.checked ? Theme.accent
                            : (control.down ? Theme.textStrong : (control.hovered ? Theme.text : Theme.textMuted))

    implicitWidth: touch ? Theme.touchHeight : Theme.controlHeight
    implicitHeight: implicitWidth
    padding: 0
    focusPolicy: Qt.StrongFocus
    display: AbstractButton.IconOnly
    Accessible.name: label

    AppToolTip {
        visible: control.showTooltip && control.hovered && control.label !== ""
        text: control.label
        shortcut: control.shortcut
    }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: control.iconName
            color: control.enabled ? control.iconColor : Theme.border
            size: control.touch ? 20 : 16
        }
    }

    background: Rectangle {
        radius: control.touch ? width / 2 : Theme.radiusMd
        color: control.checked ? (control.hovered ? Theme.tint(Theme.accent, 0.25) : Theme.accentSoft)
             : control.down ? Theme.hover
             : (control.hovered ? Theme.subtle : "transparent")
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.focusRing
    }
}
