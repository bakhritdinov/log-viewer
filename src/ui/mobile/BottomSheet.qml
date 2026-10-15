import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// A sheet from the bottom: grab handle, title with ×, scrolling content and an
// optional action pinned to the bottom. Height follows the content, at most up
// to 56 px from the top. Closes by swiping down, tapping the scrim, × or Back.
Popup {
    id: root

    property string title
    default property alias content: body.data
    property alias footer: footerSlot.data
    // Above the scrolling content, not scrolled with it (a search field).
    property alias pinned: pinnedSlot.data
    // Almost the whole screen whatever the content (lists that change while typing).
    property bool tall: false

    parent: Overlay.overlay
    x: 0
    width: parent ? parent.width : 0
    height: tall ? (parent ? parent.height : 800) - 56 : Math.min(sheet.implicitHeight, (parent ? parent.height : 800) - 56)
    y: (parent ? parent.height : 0) - height + drag.offset
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Theme.overlay }
    onAboutToShow: bodyFlick.contentY = 0

    enter: Transition { NumberAnimation { property: "y"; from: root.parent ? root.parent.height : 0; duration: 180; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "y"; to: root.parent ? root.parent.height : 0; duration: 150; easing.type: Easing.InCubic } }

    background: Rectangle {
        color: Theme.surface
        topLeftRadius: 16
        topRightRadius: 16
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
    }

    // Swiping the handle or the title down closes the sheet.
    QtObject {
        id: drag
        property real offset: 0
    }

    contentItem: ColumnLayout {
        id: sheet
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title

        Item {
            id: handleArea
            Layout.fillWidth: true
            implicitHeight: titleRow.implicitHeight + 18
            DragHandler {
                target: null
                yAxis.enabled: true
                xAxis.enabled: false
                onTranslationChanged: drag.offset = Math.max(0, translation.y)
                onActiveChanged: if (!active) {
                    if (drag.offset > 80) root.close()
                    drag.offset = 0
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                width: 36; height: 4; radius: 2
                color: Theme.textDisabled
            }
            RowLayout {
                id: titleRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 4
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontXl + 1
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
                IconButton { touch: true; iconName: "close"; label: qsTr("Close"); onClicked: root.close() }
            }
        }
        ColumnLayout {
            id: pinnedSlot
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 10
            visible: children.length > 0
            spacing: 12
        }
        Flickable {
            id: bodyFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: body.implicitHeight
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: body
                width: parent.width
                spacing: 0
            }
        }
        ColumnLayout {
            id: footerSlot
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.topMargin: 8
            visible: children.length > 0
        }
    }
}
