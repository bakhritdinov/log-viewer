import QtQuick
import QtQuick.Layouts

// Divider between groups of AppMenu items.
Item {
    Layout.fillWidth: true
    implicitHeight: 9
    Accessible.ignored: true
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 4
        width: parent.width - 8
        height: 1
        color: Theme.border
    }
}
