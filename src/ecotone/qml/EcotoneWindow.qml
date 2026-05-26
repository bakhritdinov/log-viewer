import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

ApplicationWindow {
    id: ecotoneWindow
    width: 1340
    height: 800
    minimumWidth: 980
    minimumHeight: 560
    title: qsTr("Ecotone — Error Messages")

    palette {
        window: Theme.bg
        windowText: Theme.text
        base: Theme.bgRaised
        text: Theme.text
        button: Theme.bgSubtle
        buttonText: Theme.text
        highlight: Theme.accent
        highlightedText: Theme.textOnAccent
    }

    background: Rectangle { color: Theme.bg }

    // Active environment.
    property string envName: (typeof configManager !== "undefined" && configManager !== null)
                              ? configManager.currentEnv : "DEV"

    readonly property bool loading: (typeof ecotoneClient !== "undefined" && ecotoneClient !== null)
                                     ? ecotoneClient.loading : false
    readonly property bool connected: (typeof ecotoneClient !== "undefined" && ecotoneClient !== null)
                                       ? ecotoneClient.connected : false

    // Filter + pagination state. searchText is kept as a property so the
    // backend signature stays stable for when the UI returns — for now it
    // is always "".
    property string channelFilter: ""
    property string searchText:    ""
    property int    currentPage:   0
    readonly property int pageSize: 50
    readonly property int totalPages: Math.max(1, Math.ceil(rowsTotal / pageSize))

    property var    channels: []   // populated from ecotoneClient.channelsReceived
    property string lastRefreshAt: ""
    property int    rowsLoaded: 0
    property int    rowsTotal:  0
    property string lastError: ""

    // Global replay-request totals across the whole ecotone_replay_requests
    // table, refreshed by replayStatusPoll every 5s while connected.
    property var replayCounts: ({ pending: 0, processing: 0, done: 0, failed: 0 })

    function loadPage() {
        if (typeof ecotoneClient === "undefined" || ecotoneClient === null) return
        if (!ecotoneClient.connected) return
        ecotoneClient.fetchErrors(pageSize, currentPage * pageSize, channelFilter, searchText)
    }

    // Pull creds, validate, then load page 0 + channels list.
    function reload() {
        if (typeof ecotoneClient === "undefined" || ecotoneClient === null) return
        if (typeof ecotoneConfig === "undefined" || ecotoneConfig === null) return
        const host = ecotoneConfig.host(envName)
        if (!host) {
            lastError = qsTr("No credentials configured for %1 — open Settings to set host/port/database.").arg(envName)
            return
        }
        lastError = ""
        ecotoneClient.connectDb(
            host,
            ecotoneConfig.port(envName),
            ecotoneConfig.database(envName),
            ecotoneConfig.user(envName),
            ecotoneConfig.password(envName))
    }

    function switchEnv(newEnv) {
        if (envName === newEnv) return
        envName = newEnv
        if (typeof configManager !== "undefined" && configManager !== null) {
            configManager.currentEnv = newEnv
        }
        if (typeof errorMessagesModel !== "undefined" && errorMessagesModel !== null) {
            errorMessagesModel.clear()
        }
        currentPage = 0
        channels = []
        rowsLoaded = 0
        rowsTotal  = 0
        channelFilter = ""
        reload()
    }

    function applyFilters() {
        currentPage = 0
        loadPage()
    }

    Connections {
        target: typeof ecotoneClient !== "undefined" ? ecotoneClient : null
        ignoreUnknownSignals: true
        function onConnectionEstablished() {
            // No window-visibility gate any more: testConnection now uses a
            // separate signal, so connectionEstablished is only emitted by
            // the real connectDb path which is always intentional.
            ecotoneClient.fetchChannels()
            ecotoneClient.fetchReplayStatusSummary()
            ecotoneClient.fetchErrors(ecotoneWindow.pageSize, 0,
                                       ecotoneWindow.channelFilter,
                                       ecotoneWindow.searchText)
        }
        function onReplayStatusSummaryReceived(counts) {
            ecotoneWindow.replayCounts = counts
        }
        function onConnectionFailed(reason) {
            ecotoneWindow.lastError = qsTr("Connection failed: ") + reason
        }
        function onChannelsReceived(list) {
            ecotoneWindow.channels = list
        }
        function onErrorsReceived(entries, total) {
            ecotoneWindow.rowsLoaded = entries.length
            ecotoneWindow.rowsTotal  = total
            ecotoneWindow.lastRefreshAt = Qt.formatDateTime(new Date(), "hh:mm:ss")
            ecotoneWindow.lastError = ""
        }
        function onErrorOccurred(msg) {
            ecotoneWindow.lastError = msg
        }
        function onReplayQueued(firstRequestId, count) {
            ecotoneWindow.lastError = ""
            ecotoneWindow.lastRefreshAt = qsTr("queued #%1 · %2 msg(s) · %3")
                .arg(firstRequestId).arg(count)
                .arg(Qt.formatDateTime(new Date(), "hh:mm:ss"))
            ecotoneWindow.loadPage()
            ecotoneClient.fetchReplayStatusSummary()   // refresh global pills
        }
        function onReplayFailed(reason) {
            ecotoneWindow.lastError = reason
        }
    }

    // ── Toolbar row 1 — title, env switcher, primary actions ───────────────
    header: Rectangle {
        color: Theme.bgRaised
        // Drive height from the layout so the filter-strip wrapper (which is
        // now its own Rectangle) is counted, rather than only the inner RowLayout.
        implicitHeight: headerCol.implicitHeight
        ColumnLayout {
            id: headerCol
            anchors.fill: parent
            spacing: 0

            RowLayout {
                id: toolbar
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.hToolbar + 6
                Layout.leftMargin: Theme.sp4
                Layout.rightMargin: Theme.sp4
                spacing: Theme.sp3

                ColumnLayout {
                    spacing: 0
                    Label {
                        text: qsTr("Ecotone Error Messages")
                        font.pixelSize: Theme.fsLg
                        font.bold: true
                        color: Theme.text
                    }
                    Label {
                        text: ecotoneWindow.connected
                              ? qsTr("Connected · showing %1 of %2 rows").arg(ecotoneWindow.rowsLoaded).arg(ecotoneWindow.rowsTotal)
                              : qsTr("Not connected")
                        color: ecotoneWindow.connected ? Theme.success : Theme.textMuted
                        font.pixelSize: Theme.fsXs
                    }
                }

                Item { width: Theme.sp4 }

                // Env switcher.
                Rectangle {
                    Layout.preferredHeight: Theme.hButton + 4
                    color: Theme.bgInput
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.rMd
                    implicitWidth: envRow.implicitWidth + 4

                    RowLayout {
                        id: envRow
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 0
                        Repeater {
                            model: ["DEV", "PROD"]
                            Rectangle {
                                id: envChip
                                required property string modelData
                                property bool active: ecotoneWindow.envName === modelData
                                implicitWidth: 64
                                Layout.fillHeight: true
                                radius: Theme.rSm
                                color: active ? Theme.successDim
                                     : (envMouse.containsMouse ? Theme.bgSubtle : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                                Text {
                                    anchors.centerIn: parent
                                    text: envChip.modelData
                                    color: envChip.active ? Theme.textOnAccent : Theme.text
                                    font.bold: true
                                    font.pixelSize: Theme.fsXs
                                    font.letterSpacing: 0.5
                                }
                                MouseArea {
                                    id: envMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ecotoneWindow.switchEnv(envChip.modelData)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                SecondaryButton {
                    text: qsTr("Replay FIFO group…")
                    enabled: ecotoneWindow.connected
                    onClicked: replayFifoGroupDialog.open()
                }
                PrimaryButton {
                    text: ecotoneWindow.loading ? qsTr("Loading…") : qsTr("Refresh")
                    enabled: !ecotoneWindow.loading
                    onClicked: {
                        if (!ecotoneWindow.connected) ecotoneWindow.reload()
                        else ecotoneWindow.loadPage()
                    }
                }
                SecondaryButton {
                    text: qsTr("Settings")
                    onClicked: settingsDialog.open()
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

            // Filter strip sits on a darker background so it visually
            // separates from the title/env toolbar above — they were blending
            // into a single panel before.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.hToolbar + 4
                color: Theme.bgInput

            // ── Toolbar row 2 — channel filter + pagination ──────────────
            // Search input was removed temporarily — backend still accepts a
            // searchText arg (always "" for now) so it can be brought back
            // without further plumbing changes.
            RowLayout {
                id: filterStrip
                anchors.fill: parent
                anchors.leftMargin: Theme.sp4
                anchors.rightMargin: Theme.sp4
                spacing: Theme.sp2

                Label {
                    text: qsTr("Channel")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsSm
                }
                ComboBox {
                    id: channelCombo
                    Layout.preferredWidth: 320
                    implicitHeight: Theme.hButton
                    // First entry is the "all channels" sentinel.
                    model: [qsTr("All channels")].concat(ecotoneWindow.channels)
                    currentIndex: ecotoneWindow.channelFilter === ""
                                  ? 0
                                  : Math.max(0, ecotoneWindow.channels.indexOf(ecotoneWindow.channelFilter) + 1)
                    onActivated: (index) => {
                        ecotoneWindow.channelFilter = index === 0 ? "" : ecotoneWindow.channels[index - 1]
                        ecotoneWindow.applyFilters()
                    }
                }

                SecondaryButton {
                    visible: ecotoneWindow.channelFilter !== ""
                    text: qsTr("Clear")
                    onClicked: {
                        ecotoneWindow.channelFilter = ""
                        channelCombo.currentIndex = 0
                        ecotoneWindow.applyFilters()
                    }
                }

                Item { width: Theme.sp3 }

                // ── Global replay-request counts across the whole table ────
                Label {
                    text: qsTr("Replay:")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsSm
                }
                StatusPill { status: "pending";    count: ecotoneWindow.replayCounts.pending    || 0 }
                StatusPill { status: "processing"; count: ecotoneWindow.replayCounts.processing || 0 }
                StatusPill { status: "done";       count: ecotoneWindow.replayCounts.done       || 0 }
                StatusPill { status: "failed";     count: ecotoneWindow.replayCounts.failed     || 0 }

                Item { Layout.fillWidth: true }

                // Pagination — right-aligned.
                SecondaryButton {
                    text: "‹"
                    enabled: ecotoneWindow.currentPage > 0 && !ecotoneWindow.loading
                    onClicked: { ecotoneWindow.currentPage = Math.max(0, ecotoneWindow.currentPage - 1); ecotoneWindow.loadPage() }
                }
                Label {
                    text: qsTr("Page %1 of %2").arg(ecotoneWindow.currentPage + 1).arg(ecotoneWindow.totalPages)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsSm
                }
                SecondaryButton {
                    text: "›"
                    enabled: ecotoneWindow.currentPage + 1 < ecotoneWindow.totalPages && !ecotoneWindow.loading
                    onClicked: { ecotoneWindow.currentPage = ecotoneWindow.currentPage + 1; ecotoneWindow.loadPage() }
                }
            }
            }  // closes filter-strip wrapper Rectangle
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.borderMuted }
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Vertical

        EcotoneTableView {
            id: table
            SplitView.fillHeight: true
            SplitView.minimumHeight: 200
            onReplayOneRequested: (messageId) => {
                console.log(">>> EcotoneWindow.onReplayOneRequested:", messageId)
                replayConfirm.mode = "one"
                replayConfirm.targetId = messageId
                replayConfirm.affectedCount = 1
                replayConfirm.open()
            }
        }
        EcotoneDetailsPane {
            id: details
            SplitView.preferredHeight: 300
            SplitView.minimumHeight: 100
            messageId:        table.selectedMessageId
            failedAt:         table.selectedFailedAt
            channel:          table.selectedChannel
            contractId:       table.selectedContractId
            payload:          table.selectedPayload
            headers:          table.selectedHeaders
            replayStatus:     table.selectedReplayStatus
            replayRequestId:  table.selectedReplayRequestId
        }
    }

    EcotoneSettingsDialog {
        id: settingsDialog
        onSaved: {
            ecotoneWindow.envName = (typeof configManager !== "undefined" && configManager !== null)
                                    ? configManager.currentEnv : "DEV"
            if (typeof errorMessagesModel !== "undefined" && errorMessagesModel !== null) {
                errorMessagesModel.clear()
            }
            ecotoneWindow.currentPage = 0
            ecotoneWindow.channelFilter = ""
            ecotoneWindow.reload()
        }
    }

    ReplayConfirmDialog {
        id: replayConfirm
        envName: ecotoneWindow.envName
        onConfirmed: {
            console.log(">>> ReplayConfirmDialog.onConfirmed mode=" + mode + " targetId=" + targetId)
            if (typeof ecotoneClient === "undefined" || ecotoneClient === null) return
            if (mode === "one") ecotoneClient.replayOne(targetId)
        }
    }

    ReplayFifoGroupDialog {
        id: replayFifoGroupDialog
        envName: ecotoneWindow.envName
        onConfirmed: (groupId, searchValue) => {
            if (typeof ecotoneClient === "undefined" || ecotoneClient === null) return
            ecotoneClient.replayFifoGroup(groupId, searchValue)
        }
    }

    // 5 sec polling of the replay-request summary while the window is open
    // AND the connection is alive. EcotoneClient::fetchReplayStatusSummary
    // is silent on failure so a transient blip won't spam the user.
    Timer {
        id: statusSummaryPoll
        interval: 5000
        repeat: true
        running: ecotoneWindow.visible && ecotoneWindow.connected
        onTriggered: ecotoneClient.fetchReplayStatusSummary()
    }

    footer: ToolBar {
        height: 26
        background: Rectangle { color: Theme.bgInput; border.color: Theme.borderMuted; border.width: 1 }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp4
            anchors.rightMargin: Theme.sp4
            spacing: Theme.sp2

            Rectangle {
                width: 8; height: 8; radius: 4
                color: ecotoneWindow.loading ? Theme.warn
                       : (ecotoneWindow.lastError ? Theme.danger
                          : (ecotoneWindow.connected ? Theme.success : Theme.textDim))
            }
            Label {
                text: ecotoneWindow.loading ? qsTr("Loading…")
                      : (ecotoneWindow.lastError ? ecotoneWindow.lastError
                         : (ecotoneWindow.connected
                            ? qsTr("Ready · last refresh %1").arg(ecotoneWindow.lastRefreshAt || "—")
                            : qsTr("Configure DB connection in Settings")))
                color: ecotoneWindow.lastError ? Theme.danger : Theme.textMuted
                font.pixelSize: Theme.fsSm
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    Component.onCompleted: reload()
}
