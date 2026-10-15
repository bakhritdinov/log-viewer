pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// All keyboard shortcuts (the same list Main registers).
ListView {
    id: root

    property var shortcuts: []          // [{ keys: [...], text }]

    clip: true
    topMargin: 16
    bottomMargin: 16
    model: shortcuts
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { }

    delegate: Item {
        id: line
        required property var modelData
        width: ListView.view.width
        height: 40

        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 24; anchors.rightMargin: 24
            height: 1
            color: Theme.borderMuted
        }

        RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: line.modelData.text
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.text
        }
        Row {
            spacing: 4
            Repeater {
                model: line.modelData.keys
                delegate: Kbd { required property string modelData; text: modelData }
            }
        }
        }
    }
}
