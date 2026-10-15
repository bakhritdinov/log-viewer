import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Live tail: newest entries on top. Scrolling away or opening an entry pauses
// (new lines are buffered, nothing jumps); "N new · resume" or Space continues.
ColumnLayout {
    id: root

    readonly property var live: Session.live
    property int selectedRow: -1
    property alias table: table

    // Why the stream is paused: "button", "scroll" or "entry" (an open entry
    // must not slide away; closing it resumes).
    property string pauseReason: "button"

    spacing: 0

    onSelectedRowChanged: {
        if (selectedRow >= 0 && !live.paused) { pauseReason = "entry"; live.paused = true }
        else if (selectedRow < 0 && live.paused && pauseReason === "entry") live.resume()
    }
    Connections {
        target: root.live
        function onRunningChanged() { root.pauseReason = "button"; root.selectedRow = -1 }
    }

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
            opacity: root.live.failing ? 0.55 : 1
            model: root.live.logs
            currentRow: root.selectedRow
            onRowClicked: row => root.selectedRow = root.selectedRow === row ? -1 : row
            onMoveRequested: delta => root.selectedRow = Math.max(0, root.selectedRow + delta)
            view.onMovementStarted: if (!view.atYBeginning) { root.pauseReason = "scroll"; root.live.paused = true }
            view.onAtYBeginningChanged: if (view.atYBeginning && view.moving) root.live.paused = false
        }

        // Nothing has arrived since live tail started.
        Column {
            anchors.centerIn: parent
            visible: root.live.bufferCount === 0 && !root.live.failing
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 12; height: 12; radius: 6
                color: Theme.danger
                SequentialAnimation on opacity {
                    running: root.visible && root.live.bufferCount === 0
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.35; duration: 600 }
                    NumberAnimation { from: 0.35; to: 1; duration: 600 }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Waiting for new entries of %1").arg(Session.app)
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg
                font.weight: Font.Medium
                color: Theme.textStrong
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Checking every 2 s. Entries that arrive after live tail was turned on are shown.")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }

        AppButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40
            visible: root.live.paused && root.live.pending > 0
            variant: "primary"
            iconName: "arrowUp"
            text: qsTr("%n new · resume live", "", root.live.pending)
            onClicked: { root.selectedRow = -1; root.live.resume(); table.view.positionViewAtBeginning() }
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
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 4
                    color: root.live.failing ? Theme.danger : root.live.paused ? Theme.warn : Theme.success
                }
                Text {
                    text: root.live.failing ? qsTr("Stream interrupted")
                        : !root.live.paused ? qsTr("Streaming · ~%1 lines/s").arg(root.live.ratePerSecond.toLocaleString(Qt.locale(), "f", 0))
                        : root.pauseReason === "scroll" ? qsTr("Paused: you scrolled down")
                        : root.pauseReason === "entry" ? qsTr("Paused: an entry is open")
                        : qsTr("Paused · new entries are buffered")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: root.live.failing ? Theme.dangerText : root.live.paused ? Theme.warnText : Theme.success
                }
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                readonly property bool full: root.live.bufferCount >= root.live.capacity
                text: full ? qsTr("Buffer full: %1 lines, the oldest are dropped").arg(root.live.capacity.toLocaleString(Qt.locale(), "f", 0))
                           : qsTr("Buffer holds %1 of %2 lines · the oldest are dropped")
                             .arg(root.live.bufferCount.toLocaleString(Qt.locale(), "f", 0))
                             .arg(root.live.capacity.toLocaleString(Qt.locale(), "f", 0))
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: full ? Theme.warnText : Theme.textMuted
            }
            Text {
                text: root.pauseReason === "entry" && root.live.paused ? qsTr("Esc — close and resume") : qsTr("Space — pause / resume")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
    }
}
