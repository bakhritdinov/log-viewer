import QtQuick
import QtQuick.Controls.Basic

// Text button with an optional leading icon.
// variant: "secondary" (default), "primary", "ghost", "danger", "link".
// touch: 44 px tall for mobile; otherwise 32 px.
Button {
    id: control

    property string variant: "secondary"
    property string iconName
    property bool touch: false

    readonly property color _fg: {
        if (!enabled) return Theme.textMuted
        switch (variant) {
        case "primary": return Theme.textOnAccent
        case "danger": return Theme.dangerText
        case "link": return Theme.accent
        }
        return Theme.text
    }

    implicitHeight: touch ? Theme.touchHeight : Theme.controlHeight
    implicitWidth: Math.max(implicitHeight, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: variant === "link" ? 4 : (touch ? 16 : 12)
    rightPadding: leftPadding
    font.family: Theme.sans
    font.pixelSize: touch ? Theme.fontLg : Theme.fontMd
    font.weight: variant === "primary" ? Font.DemiBold : Font.Medium
    focusPolicy: Qt.StrongFocus
    Accessible.name: text

    contentItem: Row {
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
            font: control.font
            color: control._fg
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        radius: control.touch ? Theme.radiusLg : Theme.radiusMd
        color: {
            switch (control.variant) {
            case "primary":
                return !control.enabled ? Theme.subtle
                     : control.down ? Theme.successBorder : Theme.successStrong
            case "ghost":
            case "link":
                return control.down || control.hovered ? Theme.subtle : "transparent"
            case "danger":
                return control.down ? Theme.dangerSoft : (control.hovered ? Theme.subtle : "transparent")
            }
            return control.down ? Theme.hover : (control.hovered ? Theme.hover : Theme.subtle)
        }
        border.width: control.variant === "ghost" || control.variant === "link" ? 0 : 1
        border.color: control.visualFocus ? Theme.focusRing
                    : control.variant === "primary" ? Theme.successBorder
                    : control.variant === "danger" ? Theme.dangerBorder
                    : Theme.border
    }
}
