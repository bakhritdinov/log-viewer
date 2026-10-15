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

    // Rows are shortcuts ({ keys, text }) or group headings ({ header }).
    delegate: Item {
        id: line
        required property var modelData
        readonly property bool isHeader: line.modelData.header !== undefined
        width: ListView.view.width
        height: isHeader ? 36 : 40

        Text {
            visible: line.isHeader
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: line.isHeader ? line.modelData.header : ""
            font.family: Theme.sans
            font.pixelSize: Theme.fontXs
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            font.capitalization: Font.AllUppercase
            color: Theme.textMuted
        }

        Rectangle {
            visible: !line.isHeader
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 24; anchors.rightMargin: 24
            height: 1
            color: Theme.borderMuted
        }

        RowLayout {
            visible: !line.isHeader
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: line.isHeader ? "" : line.modelData.text
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.text
            }
            Row {
                spacing: 4
                Repeater {
                    model: line.isHeader ? [] : line.modelData.keys
                    delegate: Kbd { required property string modelData; text: modelData }
                }
            }
        }
    }
}
