pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Live tail over the Logs section: new entries on top (green for 1.5 s),
// paused by the button, by scrolling down, by opening an entry or by leaving
// the app; while paused the new ones wait in the buffer. × or Back leaves.
Rectangle {
    id: root

    signal entryRequested(int row)

    readonly property var live: Session.live
    // Why it is paused: "button", "scroll", "entry" or "away" (the app was left).
    property string pauseReason

    function pause(reason) { pauseReason = reason; live.paused = true }
    function resume() {
        pauseReason = ""
        live.resume()
        list.positionViewAtBeginning()
    }
    function num(n) { return n.toLocaleString(Qt.locale(), "f", 0) }

    color: Theme.bg
    Keys.onBackPressed: live.stop()

    // The app was left (phone locked, another app): pause, and say how many
    // came meanwhile on return.
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive && root.live.running && !root.live.paused) root.pause("away")
        }
    }

    // New entries glow for 1.5 s: the ones newer than the top before they came.
    property real previousTopMs: Infinity
    property real topMs: 0
    Connections {
        target: root.live
        function onBufferChanged() {
            const top = root.live.logs.totalCount > 0 ? root.live.logs.rowData(0).timeMs : 0
            if (top > root.topMs && !root.live.paused) {
                root.previousTopMs = root.topMs > 0 ? root.topMs : Infinity
                root.topMs = top
                freshTimer.restart()
            }
        }
        function onRunningChanged() { root.topMs = 0; root.previousTopMs = Infinity; root.pauseReason = "" }
    }
    Timer { id: freshTimer; interval: 1500; onTriggered: root.previousTopMs = Infinity }

    // A minute without entries while the search filters some out: say so.
    property bool quietTooLong: false
    Timer {
        running: root.live.running && root.live.bufferCount === 0 && !root.live.failing
        interval: 60000
        onRunningChanged: root.quietTooLong = false
        onTriggered: root.quietTooLong = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Where, LIVE / PAUSED, pause or resume, leave.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            color: Theme.surface
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: Session.environmentName + " · " + Session.namespaceName
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontXs
                        color: Theme.textMuted
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Session.app
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXl
                        font.weight: Font.DemiBold
                        color: Theme.textStrong
                    }
                }
                Rectangle {
                    implicitHeight: 26
                    implicitWidth: stateRow.implicitWidth + 16
                    radius: 13
                    color: root.live.paused ? Theme.warnSoft : Theme.dangerSoft
                    border.width: 1
                    border.color: root.live.paused ? Theme.tint(Theme.warn, 0.5) : Theme.dangerBorder
                    Row {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.live.paused
                            width: 8; height: 8; radius: 4
                            color: Theme.danger
                            SequentialAnimation on opacity {
                                running: root.live.running && !root.live.paused && root.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 600 }
                                NumberAnimation { to: 1; duration: 600 }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.live.paused ? qsTr("PAUSED") : "LIVE"
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Bold
                            color: root.live.paused ? Theme.warnText : Theme.dangerText
                        }
                    }
                }
                IconButton {
                    touch: true
                    iconName: root.live.paused ? "play" : "pause"
                    label: root.live.paused ? qsTr("Resume") : qsTr("Pause")
                    onClicked: root.live.paused ? root.resume() : root.pause("button")
                }
                IconButton {
                    touch: true
                    iconName: "close"
                    label: qsTr("Leave live tail")
                    onClicked: root.live.stop()
                }
            }
        }

        // The conditions that apply, and the rate.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: Theme.surface
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 8
                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    contentWidth: liveChips.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    FilterChipBar {
                        id: liveChips
                        touch: true
                        model: Session.chips
                        // Changing the conditions in live means a new tail.
                        onRemoveRequested: index => { Session.removeChip(index); root.live.stop(); root.live.start() }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Session.chips.count === 0
                        text: qsTr("all entries")
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontMd
                        color: Theme.textMuted
                    }
                }
                Text {
                    visible: !root.live.paused && root.live.ratePerSecond > 0
                    text: qsTr("~%1/s").arg(root.live.ratePerSecond.toLocaleString(Qt.locale(), "f", root.live.ratePerSecond < 10 ? 1 : 0))
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
        }

        ErrorBanner {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.bottomMargin: 0
            visible: root.live.failing
            touch: true
            error: root.live.error
            onActionTriggered: { root.live.stop(); root.live.start() }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                topMargin: 12
                bottomMargin: 12
                leftMargin: 12
                rightMargin: 12
                spacing: 8
                clip: true
                opacity: root.live.failing ? 0.55 : 1
                model: root.live.logs
                Accessible.role: Accessible.List
                Accessible.name: qsTr("Log stream")
                // Scrolling down pauses; back at the top resumes.
                onMovementStarted: if (!atYBeginning && !root.live.paused) root.pause("scroll")
                onAtYBeginningChanged: if (atYBeginning && moving && root.pauseReason === "scroll") root.resume()
                delegate: LogCard {
                    width: ListView.view.width - 24
                    lines: Math.max(2, Session.prefs.messageLines)
                    fresh: timeMs > root.previousTopMs
                    onClicked: { root.pause("entry"); root.entryRequested(index) }
                }
            }

            // Paused with new entries waiting.
            AbstractButton {
                id: pending
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                z: 1
                visible: root.live.paused && root.live.pending > 0
                implicitHeight: 36
                implicitWidth: pendingRow.implicitWidth + 28
                Accessible.name: pendingLabel.text
                onClicked: root.resume()
                background: Rectangle {
                    radius: 18
                    color: pending.pressed ? Qt.darker(Theme.accentStrong, 1.15) : Theme.accentStrong
                }
                contentItem: Item {
                    Row {
                        id: pendingRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "arrowUp"; size: 14; color: Theme.textOnAccent }
                        Text {
                            id: pendingLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.pauseReason === "away"
                                  ? qsTr("While you were away: %n new · resume", "", root.live.pending)
                                  : qsTr("%n new · resume", "", root.live.pending)
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.DemiBold
                            color: Theme.textOnAccent
                        }
                    }
                }
            }

            // Waiting for the first entries.
            EmptyState {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                anchors.verticalCenter: parent.verticalCenter
                visible: root.live.bufferCount === 0 && !root.live.failing
                touch: true
                iconName: "clock"
                title: qsTr("Waiting for new entries")
                message: qsTr("Checking every %1 s. Entries that arrive after live tail was turned on are shown.").arg(Math.round(Session.prefs.liveIntervalMs / 1000))
                Text {
                    width: parent ? parent.width : 0
                    visible: root.quietTooLong && Session.chips.count > 0
                    text: qsTr("The search conditions may hide entries.")
                    wrapMode: Text.Wrap
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontLg
                    color: Theme.warnText
                }
                AppButton {
                    width: parent ? parent.width : 0
                    visible: root.quietTooLong && Session.chips.count > 0
                    touch: true
                    text: qsTr("Clear the search")
                    onClicked: { Session.clearSearch(); root.live.stop(); root.live.start() }
                }
            }
        }

        // The state of the stream and the buffer.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: Theme.surface
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.live.failing ? Theme.danger : root.live.paused ? Theme.warn : Theme.success
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.live.failing ? qsTr("Stream interrupted")
                        : !root.live.paused ? qsTr("Streaming · buffer %1 of %2").arg(root.num(root.live.bufferCount)).arg(root.num(root.live.capacity))
                        : root.pauseReason === "scroll" ? qsTr("Paused: you scrolled down")
                        : root.pauseReason === "entry" ? qsTr("Paused: an entry is open")
                        : qsTr("Paused · new entries are buffered")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    color: root.live.failing ? Theme.dangerText : root.live.paused ? Theme.warnText : Theme.text
                }
            }
        }
    }
}
