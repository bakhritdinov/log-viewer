import QtQuick
import QtQuick.Controls
import LogViewerApp

Button {
    id: root
    implicitHeight: Theme.hButton + 6
    font.pixelSize: Theme.fsMd
    font.bold: true

    background: Rectangle {
        color: !root.enabled ? Theme.bgRaised
             : root.down ? Theme.successDim
             : root.hovered ? Theme.success
             : Theme.successDim
        radius: Theme.rMd
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }

    contentItem: Text {
        text: root.text
        color: root.enabled ? Theme.textOnAccent : Theme.textDim
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        leftPadding: Theme.sp3
        rightPadding: Theme.sp3
    }
}
