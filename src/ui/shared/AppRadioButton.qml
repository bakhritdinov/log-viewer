import QtQuick
import QtQuick.Controls.Basic

// Radio button in the app's look.
RadioButton {
    id: control

    spacing: 10
    font.family: Theme.sans
    font.pixelSize: Theme.fontMd

    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height - height) / 2
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        color: Theme.inputBg
        border.width: control.checked ? 5 : 1
        border.color: control.checked ? Theme.accent : (control.visualFocus ? Theme.focusRing : Theme.textMuted)
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
