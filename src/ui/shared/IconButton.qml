import QtQuick
import QtQuick.Controls.Basic

// Icon-only button. `label` is required: it is the accessible name and the tooltip.
Button {
    id: control

    property string iconName
    required property string label
    property bool touch: false
    property bool showTooltip: !touch
    property color iconColor: control.checked ? Theme.accent : (control.hovered ? Theme.text : Theme.textMuted)

    implicitWidth: touch ? Theme.touchHeight : Theme.controlHeight
    implicitHeight: implicitWidth
    padding: 0
    focusPolicy: Qt.StrongFocus
    display: AbstractButton.IconOnly
    Accessible.name: label
    ToolTip.visible: showTooltip && hovered && label !== ""
    ToolTip.text: label
    ToolTip.delay: 500

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
        color: control.down || control.checked ? Theme.subtle : (control.hovered ? Theme.subtle : "transparent")
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.focusRing
    }
}
