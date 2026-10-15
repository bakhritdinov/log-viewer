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

    delegate: RowLayout {
        id: line
        required property var modelData
        x: 24
        width: ListView.view.width - 48
        height: 34
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
