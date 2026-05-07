import QtQuick
import LogViewerApp

Rectangle {
    id: root
    property alias text: lbl.text
    property color labelColor: Theme.textMuted

    implicitWidth: lbl.implicitWidth + Theme.sp2
    implicitHeight: 18
    color: Theme.bgSubtle
    border.color: Theme.borderMuted
    border.width: 1
    radius: 9

    Text {
        id: lbl
        anchors.centerIn: parent
        color: root.labelColor
        font.pixelSize: Theme.fsXs
        font.bold: true
    }
}
