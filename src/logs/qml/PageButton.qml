import QtQuick
import QtQuick.Controls
import LogViewerApp

Button {
    id: root
    implicitHeight: 26
    font.pixelSize: Theme.fsXs

    background: Rectangle {
        color: !root.enabled ? Theme.bgRaised
             : root.down ? Theme.bgHover
             : root.hovered ? Theme.bgSubtle
             : Theme.bgRaised
        border.color: root.enabled ? Theme.border : Theme.borderMuted
        border.width: 1
        radius: Theme.rSm
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }

    contentItem: Text {
        text: root.text
        color: root.enabled ? Theme.text : Theme.textDim
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        leftPadding: Theme.sp2 + 2
        rightPadding: Theme.sp2 + 2
    }
}
