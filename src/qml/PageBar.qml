import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: root
    color: Theme.bgRaised

    property int currentPage: 0
    property int maxPage: 1
    property int logCount: 0
    property bool busy: false

    signal firstClicked()
    signal prevClicked()
    signal nextClicked()
    signal lastClicked()

    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }

    BusyIndicator {
        anchors.left: parent.left; anchors.leftMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18
        running: root.busy
        visible: running
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.sp1

        PageButton {
            text: "«"
            ToolTip.visible: hovered; ToolTip.text: "First page"; ToolTip.delay: 400
            enabled: root.currentPage > 0 && !root.busy
            onClicked: root.firstClicked()
        }
        PageButton {
            text: "‹ Newer"
            enabled: root.currentPage > 0 && !root.busy
            onClicked: root.prevClicked()
        }

        Rectangle {
            Layout.leftMargin: Theme.sp2
            Layout.rightMargin: Theme.sp2
            implicitWidth: pageLabel.implicitWidth + Theme.sp3 * 2
            implicitHeight: 24
            color: Theme.bgInput
            border.color: Theme.borderMuted
            border.width: 1
            radius: 12
            Text {
                id: pageLabel
                anchors.centerIn: parent
                text: `Page ${root.currentPage + 1} of ${root.maxPage}`
                color: Theme.text
                font.pixelSize: Theme.fsXs
                font.bold: true
            }
        }

        PageButton {
            text: "Older ›"
            enabled: root.currentPage + 1 < root.maxPage && !root.busy
            onClicked: root.nextClicked()
        }
        PageButton {
            text: "»"
            ToolTip.visible: hovered; ToolTip.text: "Last page"; ToolTip.delay: 400
            enabled: root.currentPage + 1 < root.maxPage && !root.busy
            onClicked: root.lastClicked()
        }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp1
        Badge { text: root.logCount; labelColor: Theme.text }
        Text {
            text: "logs"
            color: Theme.textMuted
            font.pixelSize: Theme.fsXs
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
