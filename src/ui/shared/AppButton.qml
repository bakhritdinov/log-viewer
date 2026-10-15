import QtQuick
import QtQuick.Controls.Basic

// Text button with an optional leading icon.
// variant: "secondary" (default), "primary", "ghost", "danger" (outlined),
// "dangerSolid" (confirmation dialogs only), "link".
// touch: 44 px tall for mobile; otherwise 32 px.
Button {
    id: control

    property string variant: "secondary"
    property string iconName
    property bool touch: false
    property string tooltip                // shown on hover
    property string shortcut               // shown in the tooltip

    readonly property color _fg: {
        if (!enabled) return Theme.textDisabled
        switch (variant) {
        case "primary":
        case "dangerSolid": return Theme.textOnAccent
        case "danger": return Theme.dangerText
        case "link": return control.down ? Theme.focusRing : Theme.accent
        }
        return control.hovered || control.down ? Theme.textStrong : Theme.text
    }

    implicitHeight: touch ? Theme.touchHeight : Theme.controlHeight
    implicitWidth: Math.max(implicitHeight, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: variant === "link" ? 4 : (touch ? 16 : 12)
    rightPadding: leftPadding
    font.weight: variant === "primary" || variant === "dangerSolid" ? Font.DemiBold : Font.Medium
    focusPolicy: Qt.StrongFocus
    Accessible.name: text

    AppToolTip {
        visible: control.hovered && control.tooltip !== ""
        text: control.tooltip
        shortcut: control.shortcut
    }

    // Centred when the button is wider than its label (full-width on the phone).
    contentItem: Item {
        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight
        Row {
            id: label
            anchors.centerIn: parent
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.iconName !== ""
                name: control.iconName
                color: control._fg
                size: control.touch ? 16 : 14
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                font.family: control.font.family
                font.pixelSize: control.font.pixelSize
                font.weight: control.font.weight
                font.underline: control.variant === "link" && control.hovered && control.enabled
                color: control._fg
            }
        }
    }

    background: Rectangle {
        radius: control.touch ? Theme.radiusLg : Theme.radiusMd
        color: {
            if (!control.enabled)
                return control.variant === "ghost" || control.variant === "link" || control.variant === "danger"
                     ? "transparent" : Theme.surface
            switch (control.variant) {
            case "primary":
                return control.down ? Theme.successPressed : (control.hovered ? Theme.successBorder : Theme.successStrong)
            case "dangerSolid":
                return control.down ? Qt.darker(Theme.dangerStrong, 1.2) : (control.hovered ? Theme.danger : Theme.dangerStrong)
            case "ghost":
                return control.down ? Theme.hover : (control.hovered ? Theme.subtle : "transparent")
            case "link":
                return "transparent"
            case "danger":
                return control.down ? Theme.tint(Theme.danger, 0.2) : (control.hovered ? Theme.dangerSoft : "transparent")
            }
            return control.down ? Theme.subtle : (control.hovered ? Theme.hover : Theme.subtle)
        }
        border.width: control.variant === "ghost" || control.variant === "link" ? (control.visualFocus ? 2 : 0) : (control.visualFocus ? 2 : 1)
        border.color: control.visualFocus ? Theme.focusRing
                    : !control.enabled ? Theme.borderMuted
                    : control.variant === "primary" ? Theme.successBorder
                    : control.variant === "dangerSolid" ? Theme.danger
                    : control.variant === "danger" ? (control.hovered ? Theme.tint(Theme.danger, 0.7) : Theme.dangerBorder)
                    : (control.hovered || control.down ? Theme.hoverBorder : Theme.border)
    }
}
