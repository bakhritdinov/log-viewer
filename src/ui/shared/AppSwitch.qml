import QtQuick
import QtQuick.Controls.Basic

// On/off switch in the app's look.
Switch {
    id: control

    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height - height) / 2
        implicitWidth: 36
        implicitHeight: 20
        radius: 10
        color: control.checked ? Theme.successStrong : Theme.subtle
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.focusRing
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Theme.textStrong
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }
}
