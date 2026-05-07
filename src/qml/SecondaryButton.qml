import QtQuick
import QtQuick.Controls
import LogViewerApp

Button {
    id: root
    implicitHeight: Theme.hButton + 6
    font.pixelSize: Theme.fsMd

    property bool active: false

    background: Rectangle {
        color: !root.enabled ? Theme.bgRaised
             : root.active ? Theme.successDim
             : root.down ? Theme.bgHover
             : root.hovered ? Theme.bgSubtle
             : Theme.bgRaised
        border.color: root.active ? Theme.success : Theme.border
        border.width: 1
        radius: Theme.rMd
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }

    contentItem: Text {
        text: root.text
        color: root.active ? Theme.textOnAccent
             : (root.enabled ? Theme.text : Theme.textDim)
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        leftPadding: Theme.sp3
        rightPadding: Theme.sp3
    }
}
