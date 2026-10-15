import QtQuick
import QtQuick.Controls.Basic

// Check box in the app's look.
CheckBox {
    id: control

    spacing: 10
    font.family: Theme.sans
    font.pixelSize: Theme.fontMd

    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height - height) / 2
        implicitWidth: 16
        implicitHeight: 16
        radius: Theme.radiusSm
        color: control.checked ? Theme.accentStrong : Theme.inputBg
        border.width: control.checked ? 0 : 1
        border.color: control.visualFocus ? Theme.focusRing : Theme.textMuted
        Icon {
            anchors.centerIn: parent
            visible: control.checked
            name: "check"
            size: 12
            strokeWidth: 3
            color: Theme.textOnAccent
        }
    }
    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        font: control.font
        color: Theme.text
    }
}
