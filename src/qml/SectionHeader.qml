import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

RowLayout {
    id: root
    spacing: Theme.sp2

    property string title: ""
    property int    counter: -1
    property string actionText: ""
    property bool   actionVisible: false
    signal actionClicked()

    Text {
        text: root.title
        color: Theme.textMuted
        font.bold: true
        font.pixelSize: Theme.fsXs
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.5
    }

    Badge {
        visible: root.counter >= 0
        text: root.counter
    }

    Item { Layout.fillWidth: true }

    IconButton {
        visible: root.actionVisible
        text: root.actionText
        pixel: Theme.fsXs
        boxSize: 22
        iconColor: Theme.danger
        iconHoverColor: Theme.danger
        font.bold: true
        onClicked: root.actionClicked()
    }
}
