import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Live tail: newest entries on top. Scrolling away pauses (new lines are
// buffered, nothing jumps); "N new · resume" or Space continues.
ColumnLayout {
    id: root

    readonly property var live: Session.live
    property int selectedRow: -1
    property alias table: table

    spacing: 0

    ErrorBanner {
        Layout.fillWidth: true
        error: root.live.error
        visible: active
        onActionTriggered: { root.live.stop(); root.live.start() }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        LogTable {
            id: table
            anchors.fill: parent
            model: root.live.logs
            currentRow: root.selectedRow
            onRowClicked: row => root.selectedRow = row
            onMoveRequested: delta => root.selectedRow = Math.max(0, root.selectedRow + delta)
            view.onMovementStarted: if (!view.atYBeginning) root.live.paused = true
            view.onAtYBeginningChanged: if (view.atYBeginning && view.moving) root.live.paused = false
        }

        AppButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40
            visible: root.live.paused && root.live.pending > 0
            variant: "primary"
            iconName: "arrowUp"
            text: qsTr("%n new · resume live", "", root.live.pending)
            onClicked: { root.live.resume(); table.view.positionViewAtBeginning() }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36
        color: Theme.bg
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.borderMuted }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16
            Row {
                visible: root.live.paused
                spacing: 6
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 4; color: Theme.warn }
                Text {
                    text: qsTr("Paused: you scrolled down")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.warnText
                }
            }
            Text {
                text: qsTr("Buffer holds %1 of %2 lines · the oldest are dropped")
                      .arg(root.live.bufferCount.toLocaleString(Qt.locale(), "f", 0))
                      .arg(root.live.capacity.toLocaleString(Qt.locale(), "f", 0))
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            Item { Layout.fillWidth: true }
            Text {
                text: qsTr("Space — pause / resume")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
    }
}
