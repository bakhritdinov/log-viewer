import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// A screen behind a row of Settings: "‹ Settings" and the title on top, the
// content scrolling below, an optional action pinned to the bottom.
// Opaque: during a push or pop the screen slides over the previous one, which
// showed through and seemed to vanish late.
Rectangle {
    id: root
    color: Theme.bg

    property string title
    property string backLabel: qsTr("Settings")
    default property alias content: body.data
    property alias footer: footerSlot.data
    readonly property alias flickable: flick

    signal backRequested()

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: Theme.surface
        z: 1
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
        AbstractButton {
            id: back
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 44
            implicitWidth: backRow.implicitWidth + 14
            Accessible.name: root.backLabel
            onClicked: root.backRequested()
            background: Rectangle { radius: Theme.radiusMd; color: back.pressed ? Theme.subtle : "transparent" }
            contentItem: Item {
                Row {
                    id: backRow
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronLeft"; size: 20; color: Theme.accentText }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.backLabel
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXl - 1
                        font.weight: Font.Medium
                        color: Theme.accentText
                    }
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.left: back.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: root.title
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: Theme.fontXl
            font.weight: Font.DemiBold
            color: Theme.textStrong
            Accessible.role: Accessible.Heading
        }
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: bar.bottom
        anchors.bottom: footerBox.visible ? footerBox.top : parent.bottom
        contentHeight: body.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: body
            x: 16
            y: 16
            width: flick.width - 32
            spacing: 10
        }
    }

    Rectangle {
        id: footerBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0
        visible: footerSlot.children.length > 0
        height: footerSlot.implicitHeight + 24
        color: Theme.surface
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
        ColumnLayout {
            id: footerSlot
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8
        }
    }
}
