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
    property string channelFilter:     ""
    property string searchText:        ""
    // Time range and replay-status filters are persisted across sessions
    // (per-operator preference, not per-env), so the operator's curated view
    // survives a window close.
    property int    timeRangeHours:    typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null
                                       ? ecotoneConfig.timeRangeHours() : 0
    property string replayStatusFilter: typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null
                                        ? ecotoneConfig.replayStatusFilter() : ""
    property bool   autoRefresh:       typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null
                                       ? ecotoneConfig.autoRefresh() : false
    property int    currentPage:       0
    readonly property int pageSize:    50
    readonly property int totalPages:  Math.max(1, Math.ceil(rowsTotal / pageSize))

    property var    channels: []   // populated from ecotoneClient.channelsReceived
    property string lastRefreshAt: ""
    property int    rowsLoaded: 0
    property int    rowsTotal:  0
    property string lastError: ""

    // Global replay-request totals across the whole ecotone_replay_requests
    // table, refreshed by replayStatusPoll every 5s while connected.
    property var replayCounts: ({ pending: 0, processing: 0, done: 0, failed: 0 })

    // Worker-health snapshot, refreshed alongside the status summary.
    //   lastProcessedAt: Date|null — most recent processed_at in the table
    //   inflight:        number    — pending+processing
    //   recentFailures:  number    — failed within the last hour
    property var workerHealth: ({ lastProcessedAt: null, inflight: 0, recentFailures: 0 })

    function loadPage() {
        if (typeof ecotoneClient === "undefined" || ecotoneClient === null) return
        if (!ecotoneClient.connected) return
        ecotoneClient.fetchErrors(pageSize, currentPage * pageSize,
                                  channelFilter, searchText,
                                  timeRangeHours, replayStatusFilter)
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

    // "now - then" → "12s", "4m", "2h", "3d". Used by the worker-health badge.
    function formatAge(then) {
        if (!then) return "—"
        const ms = Date.now() - (then instanceof Date ? then.getTime() : new Date(then).getTime())
        if (isNaN(ms) || ms < 0) return "—"
        const s = Math.floor(ms / 1000)
        if (s < 60)    return s + "s"
        const m = Math.floor(s / 60)
        if (m < 60)    return m + "m"
        const h = Math.floor(m / 60)
        if (h < 48)    return h + "h"
        return Math.floor(h / 24) + "d"
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
            ecotoneClient.fetchWorkerHealth()
            ecotoneClient.fetchErrors(ecotoneWindow.pageSize, 0,
                                       ecotoneWindow.channelFilter,
                                       ecotoneWindow.searchText,
                                       ecotoneWindow.timeRangeHours,
                                       ecotoneWindow.replayStatusFilter)
        }
        function onReplayStatusSummaryReceived(counts) {
            ecotoneWindow.replayCounts = counts
        }
        function onWorkerHealthReceived(h) {
            ecotoneWindow.workerHealth = h
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
            ecotoneClient.fetchWorkerHealth()          // queue just grew → worker is about to be busy
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
                    text: qsTr("History")
                    enabled: ecotoneWindow.connected
                    onClicked: replayHistoryDialog.open()
                }
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

            // Filter strip uses two atomic Rows that adapt as GROUPS:
            //   wide window  → filterRow left, paginationRow right (one line)
            //   narrow       → filterRow stays on row 1, paginationRow drops
            //                   to row 2 right-aligned (or vice-versa, see
            //                   needsTwoRows). No lone "orphan" wrapping —
            //                   each group stays together.
            Rectangle {
                id: filterStrip
                Layout.fillWidth: true
                Layout.preferredHeight: needsTwoRows
                    ? (filterStripContent.rowH * 2 + Theme.sp2 * 3)
                    : (filterStripContent.rowH + Theme.sp2 * 2)
                color: Theme.bgInput

                // True when filterRow + paginationRow + margins would overflow
                // the strip's width on a single line. Picks 2-row mode then.
                readonly property bool needsTwoRows:
                    filterRow.implicitWidth + paginationRow.width
                    + Theme.sp4 * 2 + Theme.sp3 > filterStrip.width

            Item {
                id: filterStripContent
                anchors.fill: parent

                // Common height for all controls — used by both rows.
                readonly property int rowH: Theme.hButton + 4

                Row {
                    id: filterRow
                    spacing: Theme.sp3
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp4
                    anchors.top: parent.top
                    anchors.topMargin: Theme.sp2
                    height: filterStripContent.rowH

                // ── Channel filter ─────────────────────────────────────────
                Row {
                    height: filterStripContent.rowH
                    spacing: Theme.sp1
                    Label {
                        text: qsTr("Channel")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsSm
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        id: channelCombo
                        width: 260
                        height: filterStripContent.rowH
                        model: [qsTr("All channels")].concat(ecotoneWindow.channels)
                        currentIndex: ecotoneWindow.channelFilter === ""
                                      ? 0
                                      : Math.max(0, ecotoneWindow.channels.indexOf(ecotoneWindow.channelFilter) + 1)
                        onActivated: (index) => {
                            ecotoneWindow.channelFilter = index === 0 ? "" : ecotoneWindow.channels[index - 1]
                            ecotoneWindow.applyFilters()
                        }
                    }
                }

                // ── Time range — Failed-At lower bound ─────────────────────
                Row {
                    height: filterStripContent.rowH
                    spacing: Theme.sp1
                    Label {
                        text: qsTr("Range")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsSm
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        id: rangeCombo
                        width: 110
                        height: filterStripContent.rowH
                        property var rangeModel: [
                            { label: qsTr("All time"), hours: 0 },
                            { label: qsTr("Last 1h"),  hours: 1 },
                            { label: qsTr("Last 24h"), hours: 24 },
                            { label: qsTr("Last 7d"),  hours: 24 * 7 }
                        ]
                        model: rangeModel.map(function (m) { return m.label })
                        currentIndex: {
                            for (let i = 0; i < rangeModel.length; ++i) {
                                if (rangeModel[i].hours === ecotoneWindow.timeRangeHours) return i
                            }
                            return 0
                        }
                        onActivated: (index) => {
                            ecotoneWindow.timeRangeHours = rangeModel[index].hours
                            if (typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null)
                                ecotoneConfig.setTimeRangeHours(rangeModel[index].hours)
                            ecotoneWindow.applyFilters()
                        }
                    }
                }

                // ── Replay-status filter ────────────────────────────────────
                Row {
                    height: filterStripContent.rowH
                    spacing: Theme.sp1
                    Label {
                        text: qsTr("Status")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsSm
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        id: statusCombo
                        width: 110
                        height: filterStripContent.rowH
                        property var statusModel: [
                            { label: qsTr("Any"),         value: "" },
                            { label: qsTr("Not queued"),  value: "not_queued" },
                            { label: qsTr("Pending"),     value: "pending" },
                            { label: qsTr("Processing"),  value: "processing" },
                            { label: qsTr("Done"),        value: "done" },
                            { label: qsTr("Failed"),      value: "failed" }
                        ]
                        model: statusModel.map(function (m) { return m.label })
                        currentIndex: {
                            for (let i = 0; i < statusModel.length; ++i) {
                                if (statusModel[i].value === ecotoneWindow.replayStatusFilter) return i
                            }
                            return 0
                        }
                        onActivated: (index) => {
                            ecotoneWindow.replayStatusFilter = statusModel[index].value
                            if (typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null)
                                ecotoneConfig.setReplayStatusFilter(statusModel[index].value)
                            ecotoneWindow.applyFilters()
                        }
                    }
                }

                SecondaryButton {
                    height: filterStripContent.rowH
                    visible: ecotoneWindow.channelFilter !== ""
                             || ecotoneWindow.timeRangeHours !== 0
                             || ecotoneWindow.replayStatusFilter !== ""
                    text: qsTr("Clear")
                    onClicked: {
                        ecotoneWindow.channelFilter      = ""
                        ecotoneWindow.timeRangeHours     = 0
                        ecotoneWindow.replayStatusFilter = ""
                        if (typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null) {
                            ecotoneConfig.setTimeRangeHours(0)
                            ecotoneConfig.setReplayStatusFilter("")
                        }
                        channelCombo.currentIndex = 0
                        rangeCombo.currentIndex   = 0
                        statusCombo.currentIndex  = 0
                        ecotoneWindow.applyFilters()
                    }
                }

            }  // closes filterRow

            // View controls cluster — Auto + pagination. Lives in same coord
            // space as filterRow. When wide: top-right on row 1 alongside
            // filterRow. When narrow: drops below filterRow on row 2,
            // still right-anchored.
            Row {
                id: paginationRow
                height: filterStripContent.rowH
                spacing: Theme.sp2
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp4
                anchors.top: filterStrip.needsTwoRows ? filterRow.bottom : parent.top
                anchors.topMargin: Theme.sp2

                Switch {
                    id: autoRefreshSwitch
                    height: filterStripContent.rowH
                    text: qsTr("Auto")
                    font.pixelSize: Theme.fsSm
                    checked: ecotoneWindow.autoRefresh
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: {
                        ecotoneWindow.autoRefresh = checked
                        if (typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null)
                            ecotoneConfig.setAutoRefresh(checked)
                    }
                    HoverHandler { id: autoHover }
                    ToolTip.text: qsTr("Re-run the current query every 15 seconds while the window is visible.")
                    ToolTip.visible: autoHover.hovered
                    ToolTip.delay: 400
                }
                Label {
                    text: qsTr("%1 / %2").arg(ecotoneWindow.rowsLoaded).arg(ecotoneWindow.rowsTotal)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsXs
                    font.family: "Monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }
                SecondaryButton {
                    text: "‹"
                    enabled: ecotoneWindow.currentPage > 0 && !ecotoneWindow.loading
                    onClicked: { ecotoneWindow.currentPage = Math.max(0, ecotoneWindow.currentPage - 1); ecotoneWindow.loadPage() }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    text: qsTr("%1 / %2").arg(ecotoneWindow.currentPage + 1).arg(ecotoneWindow.totalPages)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsSm
                    font.family: "Monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }
                SecondaryButton {
                    text: "›"
                    enabled: ecotoneWindow.currentPage + 1 < ecotoneWindow.totalPages && !ecotoneWindow.loading
                    onClicked: { ecotoneWindow.currentPage = ecotoneWindow.currentPage + 1; ecotoneWindow.loadPage() }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            }  // closes filterStripContent Item
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
            messageId:         table.selectedMessageId
            failedAt:          table.selectedFailedAt
            channel:           table.selectedChannel
            contractId:        table.selectedContractId
            payload:           table.selectedPayload
            headers:           table.selectedHeaders
            replayStatus:      table.selectedReplayStatus
            replayRequestId:   table.selectedReplayRequestId
            replayErrorText:   table.selectedReplayErrorText
            replayProcessedAt: table.selectedReplayProcessedAt
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

    ReplayHistoryDialog {
        id: replayHistoryDialog
        envName: ecotoneWindow.envName
    }

    // 5 sec polling of the replay-request summary while the window is open
    // AND the connection is alive. EcotoneClient::fetchReplayStatusSummary
    // is silent on failure so a transient blip won't spam the user.
    Timer {
        id: statusSummaryPoll
        interval: 5000
        repeat: true
        running: ecotoneWindow.visible && ecotoneWindow.connected
        onTriggered: {
            ecotoneClient.fetchReplayStatusSummary()
            ecotoneClient.fetchWorkerHealth()
        }
    }

    // Optional auto-refresh of the main page. 15 s is rare enough not to fight
    // the operator's scroll position, frequent enough to surface new failures.
    Timer {
        id: autoRefreshTimer
        interval: 15000
        repeat: true
        running: ecotoneWindow.visible && ecotoneWindow.connected && ecotoneWindow.autoRefresh
        onTriggered: ecotoneWindow.loadPage()
    }

    // Force the worker-health badge's "Ns ago" label to recompute every second
    // so the operator sees the clock tick even between health polls. Paused
    // while a modal child window (e.g. ReplayHistoryDialog) is open — the
    // every-second binding fan-out caused scroll hitches in heavy lists.
    Timer {
        interval: 1000
        repeat: true
        running: ecotoneWindow.visible && ecotoneWindow.connected
                 && !replayHistoryDialog.visible
                 && !replayFifoGroupDialog.visible
                 && !settingsDialog.visible
        onTriggered: ecotoneWindow.workerHealth = ecotoneWindow.workerHealth
    }

    footer: ToolBar {
        // Tall enough to host Worker badge (rowH) + breathing room.
        height: Theme.hButton + 12
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

            // ── Worker health badge (relocated from filter strip) ─────────
            Rectangle {
                id: footerHealthBadge
                visible: ecotoneWindow.connected
                Layout.preferredHeight: Theme.hButton
                Layout.preferredWidth: footerHealthRow.implicitWidth + Theme.sp3 * 2
                color: Theme.bgRaised
                border.color: Theme.border
                border.width: 1
                radius: Theme.rMd

                readonly property var lastProcessed: ecotoneWindow.workerHealth.lastProcessedAt
                readonly property int inflight:      ecotoneWindow.workerHealth.inflight        || 0
                readonly property int recentFailures: ecotoneWindow.workerHealth.recentFailures || 0
                readonly property real ageSec: lastProcessed
                    ? (Date.now() - (lastProcessed instanceof Date ? lastProcessed.getTime()
                                                                   : new Date(lastProcessed).getTime())) / 1000
                    : -1
                readonly property color dotColor:
                      ageSec < 0                       ? Theme.textDim
                    : ageSec < 60                      ? Theme.success
                    : ageSec < 300                     ? Theme.warn
                    : inflight > 0                     ? Theme.danger
                    :                                    Theme.textDim
                readonly property string statusText:
                      ageSec < 0  ? qsTr("idle")
                    :               qsTr("%1 ago").arg(ecotoneWindow.formatAge(lastProcessed))

                Row {
                    id: footerHealthRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp3
                    spacing: Theme.sp2
                    Label {
                        text: qsTr("Worker")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsXs
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: footerHealthBadge.dotColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: footerHealthBadge.statusText
                        color: Theme.text
                        font.pixelSize: Theme.fsXs
                        font.family: "Monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        visible: footerHealthBadge.inflight > 0
                        text: qsTr("· %1 inflight").arg(footerHealthBadge.inflight)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsXs
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        visible: footerHealthBadge.recentFailures > 0
                        text: qsTr("· %1 failed/1h").arg(footerHealthBadge.recentFailures)
                        color: Theme.danger
                        font.pixelSize: Theme.fsXs
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                HoverHandler { id: footerHealthHover }
                ToolTip.text: footerHealthBadge.ageSec < 0
                    ? qsTr("No replay activity yet. Once the worker processes a request, the time since the last processed_at will appear here.")
                    : qsTr("Time since the most recent ecotone_replay_requests.processed_at. Green: < 1 min · Yellow: < 5 min · Red: > 5 min with queued work.")
                ToolTip.visible: footerHealthHover.hovered
                ToolTip.delay: 400
            }

            // ── Global replay-request counts (relocated from filter strip) ─
            Label {
                text: qsTr("Replay:")
                color: Theme.textMuted
                font.pixelSize: Theme.fsSm
            }
            StatusPill {
                status: "pending"; count: ecotoneWindow.replayCounts.pending || 0
                dimWhenZero: false
            }
            StatusPill {
                status: "processing"; count: ecotoneWindow.replayCounts.processing || 0
                dimWhenZero: false
            }
            StatusPill {
                status: "done"; count: ecotoneWindow.replayCounts.done || 0
                dimWhenZero: false
            }
            StatusPill {
                status: "failed"; count: ecotoneWindow.replayCounts.failed || 0
                dimWhenZero: false
            }
        }
    }

    Component.onCompleted: reload()
}
