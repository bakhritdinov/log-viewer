import QtQuick
import QtQuick.Layouts
import LogViewer.Ui

// One preference: title and an optional explanation on the left, its control
// (switch, segmented choice…) on the right.
RowLayout {
    id: root

    property string title
    property string subtitle
    default property alias control: slot.data

    Layout.fillWidth: true
    Layout.minimumHeight: 52
    spacing: 16

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            Layout.fillWidth: true
            text: root.title
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textStrong
        }
        Text {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
    }
    Item {
        id: slot
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
