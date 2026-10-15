import QtQuick
import QtQuick.Controls.Basic

// On/off switch in the app's look.
Switch {
    id: control

    property bool touch: false             // 44 × 26 for a finger

    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height - height) / 2
        implicitWidth: control.touch ? 44 : 36
        implicitHeight: control.touch ? 26 : 20
        radius: height / 2
        color: control.checked ? Theme.successStrong : Theme.subtle
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.focusRing
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: control.touch ? 20 : 14; height: width; radius: width / 2
            color: Theme.textStrong
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }
}
