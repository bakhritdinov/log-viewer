import QtQuick
import LogViewerApp

Item {
    id: root
    height: Theme.hRow
    property real seed: 0.5  // randomized message-bar width

    // Pulsing fade animation, shared visually across rows.
    SequentialAnimation on opacity {
        running: root.visible
        loops: Animation.Infinite
        NumberAnimation { from: 0.4; to: 0.9; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.9; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp2 + 22 // align with chevron column in real rows
        anchors.rightMargin: Theme.sp2
        anchors.topMargin: Theme.sp1 + 2
        anchors.bottomMargin: Theme.sp1 + 2
        spacing: Theme.sp3

        Rectangle { width: 80;  height: parent.height; radius: 3; color: Theme.bgSubtle }   // time
        Rectangle { width: 50;  height: parent.height; radius: 9; color: Theme.bgSubtle }   // level chip
        Rectangle { width: 110; height: parent.height; radius: 3; color: Theme.bgSubtle }   // service
        Rectangle {
            width: Math.max(60, root.width - 80 - 50 - 110 - Theme.sp3 * 3 - 22 - Theme.sp2 * 2)
                 * (0.55 + root.seed * 0.4)
            height: parent.height
            radius: 3
            color: Theme.bgSubtle
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.borderMuted; opacity: 0.4 }
}
