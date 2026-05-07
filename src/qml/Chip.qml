import QtQuick
import QtQuick.Controls
import LogViewerApp

Rectangle {
    id: root
    property alias text: lbl.text
    property bool   active: false
    property bool   removable: false
    signal clicked()
    signal removeClicked()

    implicitHeight: 22
    implicitWidth: row.implicitWidth + Theme.sp3
    color: root.active ? Theme.bgHover
         : (mouse.containsMouse ? Theme.bgSubtle : Theme.bgRaised)
    border.color: root.active ? Theme.accent : Theme.borderMuted
    border.width: 1
    radius: 11
    Behavior on color { ColorAnimation { duration: Theme.dFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.dFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.sp1

        Text {
            text: lbl.text
            color: root.active ? Theme.accent : Theme.text
            font.pixelSize: Theme.fsXs
            anchors.verticalCenter: parent.verticalCenter
            id: lbl
        }
        Text {
            visible: root.removable
            text: "✕"
            color: Theme.danger
            font.pixelSize: 9
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent; anchors.margins: -4
                onClicked: root.removeClicked()
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
