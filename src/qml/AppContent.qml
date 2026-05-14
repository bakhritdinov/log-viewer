import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: root
    color: Theme.bg
    
    // Properties moved from Main.qml
    property alias searchHeader: header
    property string currentNamespace: ""
    property string currentApp: ""
    property string nsLabelName: "_namespace"
    property string appLabelName: "_appName"

    // Client-side pagination over the full loaded set (no time-based slicing on backend).
    property int currentPage: 0
    readonly property int pageSize: 100
    readonly property int totalLogs: typeof logModel !== "undefined" && logModel !== null ? logModel.totalCount : 0
    readonly property int maxPage: Math.max(1, Math.ceil(totalLogs / pageSize))

    // Total seconds in the user's selected time range — drives chained loading window.
    readonly property int timeRangeSec: {
        if (header.timeRange === "Custom") {
            let f = header.customFrom ? new Date(header.customFrom).getTime() : 0
            let t = header.customTo ? new Date(header.customTo).getTime() : Date.now()
            if (f > 0 && t > f) return Math.floor((t - f) / 1000)
            return 86400
        }
        let m = header.timeRange.match(/(\d+)([smhd])/)
        if (!m) return 3600
        let n = parseInt(m[1])
        switch (m[2]) {
            case "s": return n
            case "m": return n * 60
            case "h": return n * 3600
            case "d": return n * 86400
        }
        return 3600
    }

    // Soft cap for the chained loader — initially 5000, raised by 5000 on each "Load more".
    readonly property int loadStepSize: 5000
    property int  maxLogsToLoad: loadStepSize
    // Internal: in-flight chained-load state.
    property int  _loadOffsetSec: 0
    property bool _loadCancelled: false
    property string _loadCorrelationId: ""
    // True from the moment a load starts until _commitLoad fires — used by the table to
    // freeze scroll/keyboard interaction so the list doesn't jitter while batches arrive.
    property bool chainInProgress: false
    // Snapshot of logModel.totalCount before each batch — used to detect duplicates / empty.
    property int  _lastTotal: 0
    // True when chain stopped because of the cap and there's potentially more data
    // available within the user's time range. False when the stream actually ended.
    property bool hasMore: false

    // Free-text terms extracted from the search bar (excluding `field:"value"` filters).
    // Used by LogTableView to highlight matched substrings inside the message column.
    readonly property var searchTerms: {
        if (!header.searchText) return []
        return header.searchText.split(/ AND /i)
            .map(p => p.trim())
            .filter(p => p !== "" && p !== "*" && p.indexOf(":") === -1)
    }

    onCurrentNamespaceChanged: {
        if (!currentNamespace) return
        currentPage = 0
        refreshLogs(header.searchText)
        persistSelection()
    }
    onCurrentAppChanged: {
        if (!currentApp) return
        currentPage = 0
        refreshLogs(header.searchText)
        persistSelection()
    }

    function persistSelection() {
        if (typeof configManager === "undefined" || configManager === null) return
        if (!currentNamespace || !currentApp) return
        configManager.setLastSelection(currentNamespace, currentApp, header.timeRange,
                                       header.customFrom, header.customTo)
    }

    Connections {
        target: header
        function onTimeRangeChanged() {
            root.persistSelection()
            root._recomputeBucketMs()
        }
    }

    // Histogram bucket step. Snaps to readable intervals so tick labels align
    // on round minutes/hours; aims for ~60 bars per range. Declared on root
    // (not inside ColumnLayout) so HistogramChart.onBucketClicked can reach it.
    property int _chartBucketMs: 60000
    readonly property var _bucketSteps: [
        60000, 300000, 900000, 1800000,
        3600000, 21600000, 86400000
    ]

    property var _histClickPrev: null
    function _recomputeBucketMs() {
        let span = timeRangeSec
        if (span <= 0) { _chartBucketMs = 60000; return }
        let ideal = span * 1000 / 60
        let chosen = _bucketSteps[_bucketSteps.length - 1]
        for (let i = 0; i < _bucketSteps.length; i++) {
            if (_bucketSteps[i] >= ideal) { chosen = _bucketSteps[i]; break }
        }
        _chartBucketMs = chosen
    }
    Component.onCompleted: _recomputeBucketMs()

    function _clearHistogramFilter() {
        if (_histClickPrev === null) return
        let prev = _histClickPrev
        _histClickPrev = null
        if (typeof logModel !== "undefined" && logModel !== null) {
            logModel.clearTimeLevelFilter()
        }
        if (prev.display !== undefined) {
            header.timeRangeDisplay = prev.display
        }
    }

    // Sidebar is an overlay drawer — closed by default; opened on demand.
    property bool sidebarOpen: false

    // Auto-refresh — controlled by SearchHeader's dropdown.
    property int autoRefreshSec: 0  // 0 = off
    property bool tailMode: false   // true = always reset to page 0 on tick

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SearchHeader {
            id: header
            Layout.fillWidth: true
            sidebarOpen: root.sidebarOpen
            onSearchTriggered: (query) => {
                searchDebounce.stop()
                root.currentPage = 0
                root.refreshLogs(query)
                if (typeof configManager !== "undefined" && configManager !== null) {
                    configManager.addToSearchHistory(query)
                }
            }
            onSearchTextChanged: searchDebounce.restart()
            onNamespaceChanged: (ns) => { root.currentNamespace = ns }
            onAppChanged: (app) => { root.currentApp = app }
            onToggleSidebar: root.sidebarOpen = !root.sidebarOpen
            onAutoRefreshChanged: (seconds, tail) => {
                root.autoRefreshSec = seconds
                root.tailMode = tail
            }
        }

        HistogramChart {
            id: histogram
            Layout.fillWidth: true
            // Raise z only while a bar is hovered AND sidebar is closed so the
            // hover card paints above the log table, but the sidebar (which sits
            // at root level with high z) still wins when open.
            z: (!root.sidebarOpen && hoverIndex >= 0) ? 10 : 0
            buckets: []
            bucketMs: root._chartBucketMs
            filterActive: root._histClickPrev !== null

            onResetRequested: root._clearHistogramFilter()

            Component.onCompleted: {
                if (typeof configManager !== "undefined" && configManager !== null) {
                    chartHeight = configManager.histogramHeight(chartHeight)
                    collapsed   = !configManager.histogramVisible()
                    manualBucketMs = configManager.histogramBucketMs(0)
                }
            }
            onCollapsedChanged: {
                if (typeof configManager !== "undefined" && configManager !== null) {
                    configManager.setHistogramVisible(!collapsed)
                }
            }
            onChartHeightChanged: {
                if (typeof configManager !== "undefined" && configManager !== null) {
                    configManager.setHistogramHeight(chartHeight)
                }
            }
            onBucketSizeChanged: {
                if (typeof configManager !== "undefined" && configManager !== null) {
                    configManager.setHistogramBucketMs(manualBucketMs)
                }
                root._refreshHistogram()
            }

            onBucketClicked: (fromMs, toMs, level) => {
                if (typeof logModel === "undefined" || logModel === null) return
                // Snapshot only the chip's display text — query state is left
                // untouched because filtering is purely client-side over m_full.
                if (root._histClickPrev === null) {
                    root._histClickPrev = {
                        timeRange: header.timeRange,
                        customFrom: header.customFrom,
                        customTo: header.customTo,
                        searchText: header.searchText,
                        display: header.timeRangeDisplay
                    }
                }
                // Client-side filter over m_full — no new Loki query.
                // This keeps chartCount == tableCount.
                logModel.applyTimeLevelFilter(Number(fromMs), Number(toMs), level || "")

                let fmt = (ms) => Qt.formatDateTime(new Date(ms), "MMM dd hh:mm:ss")
                let suffix = level && level !== "" ? "  ·  " + level : ""
                header.timeRangeDisplay = fmt(fromMs) + " → " + fmt(toMs) + suffix
            }
        }

        // Body — table fills, sidebar slides in over it.
        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true

            LogTableView {
                id: tableView
                anchors.fill: parent
                currentPage: root.currentPage
                maxPage: root.maxPage
                searchTerms: root.searchTerms
                hasMore: root.hasMore
                serviceField: root.appLabelName
                chainLoading: root.chainInProgress
                onLoadMoreRequested: root.loadMore()
                onTraceRequested: (traceId) => {
                    header.searchText = `trace_id: "${traceId}"`
                    root.currentPage = 0
                    root.refreshLogs(header.searchText)
                }
                onFirstPageRequested: root.gotoPage(0)
                onPrevPageRequested: root.gotoPage(root.currentPage - 1)
                onNextPageRequested: root.gotoPage(root.currentPage + 1)
                onLastPageRequested: root.gotoPage(root.maxPage - 1)
            }
        }
    }

    // Backdrop + Sidebar live at root level (outside ColumnLayout) so they
    // can overlay the entire window, not just the table area.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.sidebarOpen ? 0.4 : 0
        visible: opacity > 0
        z: 50
        Behavior on opacity { NumberAnimation { duration: Theme.dBase } }
        MouseArea { anchors.fill: parent; onClicked: root.sidebarOpen = false }
    }

    Sidebar {
        id: sidebar
        width: Math.min(360, root.width * 0.6)
        height: root.height
        y: 0
        x: root.sidebarOpen ? 0 : -width
        z: 60
        Behavior on x { NumberAnimation { duration: Theme.dBase; easing.type: Easing.OutCubic } }
    }

    // Debounce search-text edits — fire ~350ms after the user stops typing.
    Timer {
        id: searchDebounce
        interval: 350
        repeat: false
        onTriggered: {
            root.currentPage = 0
            root.refreshLogs(header.searchText)
        }
    }

    // Auto-refresh / tail mode timer.
    Timer {
        id: autoRefreshTimer
        interval: Math.max(1, root.autoRefreshSec) * 1000
        repeat: true
        running: root.autoRefreshSec > 0
        onTriggered: {
            if (root.tailMode) root.currentPage = 0
            root.refreshLogs(header.searchText)
        }
    }

    Connections {
        target: (typeof grafanaClient !== "undefined" && grafanaClient !== null) ? grafanaClient : null
        ignoreUnknownSignals: true
        function onMappingsReceived(m, nsKey, appKey) {
            if (nsKey) root.nsLabelName = nsKey
            if (appKey) root.appLabelName = appKey
            header.mappings = m
        }
        function onLogsReceived(entries) {
            // QML connections may fire before the direct C++ slot (LogModel::appendEntries)
            // has finished updating m_full. Defer one event-loop tick so totalCount reflects
            // the just-arrived batch.
            Qt.callLater(root._handleBatch)
        }
        function onErrorOccurred(error) {
            errorDialog.text = error
            errorDialog.open()
        }
    }

    Dialog {
        id: errorDialog
        property string text: ""
        title: "Request failed"
        anchors.centerIn: parent
        modal: true
        width: 480
        padding: 0

        background: Rectangle { color: Theme.bgRaised; border.color: Theme.danger; border.width: 1; radius: Theme.rLg }

        header: Rectangle {
            color: "transparent"
            implicitHeight: 44
            Row {
                anchors.left: parent.left; anchors.leftMargin: Theme.sp4
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2
                Text { text: "⚠"; color: Theme.danger; font.pixelSize: Theme.fsXl; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Text { text: errorDialog.title; color: Theme.text; font.pixelSize: Theme.fsLg; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        contentItem: ScrollView {
            implicitHeight: Math.min(errorBody.implicitHeight + Theme.sp4 * 2, 320)
            clip: true
            Label {
                id: errorBody
                width: errorDialog.width - Theme.sp4 * 2
                text: errorDialog.text
                color: Theme.text
                padding: Theme.sp4
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fsSm
                font.family: "Monospace"
            }
        }

        footer: Rectangle {
            color: "transparent"
            implicitHeight: 56
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp4
                anchors.rightMargin: Theme.sp4
                spacing: Theme.sp2
                Item { Layout.fillWidth: true }
                SecondaryButton {
                    text: "Close"
                    Layout.preferredWidth: 90
                    onClicked: errorDialog.close()
                }
                PrimaryButton {
                    text: "Retry"
                    Layout.preferredWidth: 90
                    onClicked: {
                        errorDialog.close()
                        // If discovery never completed (no ns/app), restart it.
                        // refreshLogs would just return early otherwise.
                        if (typeof grafanaClient !== "undefined" && grafanaClient !== null
                         && typeof configManager !== "undefined" && configManager !== null
                         && (!root.currentNamespace || !root.currentApp)) {
                            grafanaClient.fetchMappings(configManager.url(), configManager.token(),
                                                        configManager.datasourceUid(),
                                                        configManager.user(), configManager.password())
                        } else {
                            root.refreshLogs(header.searchText)
                        }
                    }
                }
            }
        }
    }

    function focusTable() {
        tableView.forceActiveFocus()
    }

    function _escapeLogsQL(v) {
        // LogsQL string literals: escape backslash and double quote.
        return String(v).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    }

    function toggleFilter(key, value) {
        if (!key || value === undefined || value === null) return
        let valStr = (typeof value === "string") ? value : logModel.formatValue(value)
        if (valStr === "") return

        let filter = `${key}:"${valStr}"`
        let current = header.searchText
        let trimmed = current ? current.trim() : ""

        if (trimmed === "" || trimmed === "*") {
            header.searchText = filter
        } else {
            let parts = trimmed.split(/ AND /i)
            let idx = parts.findIndex(p => p.trim() === filter)
            if (idx !== -1) {
                parts.splice(idx, 1)
                header.searchText = parts.join(" AND ")
            } else {
                header.searchText = trimmed + " AND " + filter
            }
        }
        // Stop the debounce the searchText change just restarted — we are
        // already refreshing here. Otherwise the screen flashes twice.
        searchDebounce.stop()
        refreshLogs(header.searchText)
    }

    function gotoPage(page) {
        if (page < 0 || page >= maxPage) return
        currentPage = page
        if (logModel) logModel.setPage(currentPage, pageSize)
    }

    function _buildLogsQL(query, timeFilter) {
        let labels = `${nsLabelName}="${currentNamespace}", ${appLabelName}="${currentApp}"`
        let pipeline = timeFilter ? " " + timeFilter : ""
        if (query && query !== "*" && query.trim() !== "") {
            let parts = query.split(/ AND /i)
            parts.forEach(p => {
                p = p.trim()
                if (p.indexOf(":") !== -1) {
                    let kv = p.split(":")
                    let key = kv[0].trim()
                    let val = kv.slice(1).join(":").replace(/"/g, "").trim()
                    // Leading '~' = regex filter (key:~"pattern" in LogsQL).
                    if (val.length > 1 && val[0] === "~") {
                        pipeline += ` ${key}:~"${_escapeLogsQL(val.substring(1))}"`
                    } else {
                        pipeline += ` ${key}:"${_escapeLogsQL(val)}"`
                    }
                } else {
                    pipeline += ` ~"(?i)${_escapeLogsQL(p)}"`
                }
            })
        }
        return `{${labels}}${pipeline}`
    }

    // Kicks off a fresh full-window load. Internally chains 1000-row batches until the
    // window is exhausted or maxLogsToLoad is reached, then applies the page slice.
    function refreshLogs(query) {
        if (typeof configManager === "undefined" || configManager === null
         || typeof grafanaClient === "undefined" || grafanaClient === null
         || typeof logModel === "undefined" || logModel === null) return;
        // Discovery never completed (offline at start / stale VPN): namespace and
        // app are empty. Pull mappings instead — success populates them, failure
        // surfaces an errorDialog with Retry.
        if (!currentNamespace || !currentApp) {
            grafanaClient.fetchMappings(configManager.url(), configManager.token(),
                                        configManager.datasourceUid(),
                                        configManager.user(), configManager.password())
            return
        }

        // Cancel any in-flight chain by changing correlation id.
        _loadCorrelationId = "load-" + Date.now()
        _loadCancelled = false

        currentPage = 0
        maxLogsToLoad = loadStepSize  // reset cap on every fresh load
        hasMore = false
        chainInProgress = true
        // Any explicit refresh drops the histogram filter — new data is a fresh state.
        if (logModel.hasTimeLevelFilter()) logModel.clearTimeLevelFilter()
        _histClickPrev = null
        logModel.clear()
        _lastTotal = 0
        _loadOffsetSec = 0
        // Wipe the chart so stale bars don't linger between queries.
        if (typeof histogram !== "undefined" && histogram !== null) histogram.buckets = []
        _fetchNextBatch(_loadCorrelationId)
    }

    // Continue the chain from where the previous load stopped, raising the cap by one step.
    function loadMore() {
        if (!hasMore) return
        if (typeof logModel === "undefined" || logModel === null) return
        maxLogsToLoad = logModel.totalCount + loadStepSize
        _lastTotal = logModel.totalCount
        hasMore = false
        chainInProgress = true
        _fetchNextBatch(_loadCorrelationId)
    }

    function _fetchNextBatch(corrId) {
        if (corrId !== _loadCorrelationId) return

        let from = "now-1h", to = "now"
        if (header.timeRange === "Custom") {
            from = header.customFrom || "now-1h"
            to = header.customTo || "now"
        } else if (timeRangeSec > 0) {
            from = `now-${timeRangeSec}s`
        }

        let timeFilter = `_time:${timeRangeSec}s offset ${_loadOffsetSec}s`
        let logql = _buildLogsQL(header.searchText, timeFilter)
        console.log(">>> CHAIN LOAD:", logql, "offset:", _loadOffsetSec)

        grafanaClient.queryLogs(configManager.url(), configManager.token(),
                                configManager.datasourceUid(), configManager.user(),
                                configManager.password(), logql, from, to)
    }

    function _handleBatch() {
        let nowTotal = logModel.totalCount
        let added = nowTotal - _lastTotal
        _lastTotal = nowTotal
        console.log(">>> BATCH: added", added, "total", nowTotal)

        if (added === 0) {
            hasMore = false
            _commitLoad()
            _refreshHistogram()
            return
        }

        // Update facets incrementally so the user sees fields appear as data streams in.
        _emitFacets()
        _refreshHistogram()

        let oldestMs = logModel.oldestTimestamp()
        if (oldestMs <= 0) { hasMore = false; _commitLoad(); return }

        let nowMs = Date.now()
        let offsetSec = Math.max(_loadOffsetSec + 1, Math.ceil((nowMs - oldestMs) / 1000) + 1)
        _loadOffsetSec = offsetSec

        if (offsetSec >= timeRangeSec) { hasMore = false; _commitLoad(); return }
        if (added < 1000)              { hasMore = false; _commitLoad(); return }
        if (nowTotal >= maxLogsToLoad) { hasMore = true;  _commitLoad(); return }

        _fetchNextBatch(_loadCorrelationId)
    }

    function _refreshHistogram() {
        if (typeof logModel === "undefined" || logModel === null) return
        if (typeof histogram === "undefined" || histogram === null) return
        let bucketMs = histogram.manualBucketMs > 0 ? histogram.manualBucketMs : _chartBucketMs
        histogram.bucketMs = bucketMs
        histogram.buckets = logModel.aggregateByLevel(bucketMs)
    }

    function _commitLoad() {
        chainInProgress = false
        if (logModel) logModel.setPage(currentPage, pageSize)
        _emitFacets()
        console.log(">>> LOAD COMPLETE:", logModel ? logModel.totalCount : 0, "entries")
    }

    // Aggregate field values across the *full* loaded set and push to Sidebar facets.
    function _emitFacets() {
        if (!logModel || !sidebar) return
        let facets = {}
        let all = logModel.allFields()
        if (!all || all.length === 0) {
            sidebar.facets = facets
            return
        }
        for (let i = 0; i < all.length; ++i) {
            let f = all[i]
            if (!f) continue
            for (let k in f) {
                if (k === "Line" || k === "message" || k === "Time" || k === "ts") continue
                let v = (typeof f[k] === "string") ? f[k] : String(f[k] || "")
                if (v === "") continue
                if (!facets[k]) facets[k] = {}
                facets[k][v] = (facets[k][v] || 0) + 1
            }
        }
        sidebar.facets = facets
        console.log(">>> FACETS:", Object.keys(facets).length, "fields from", all.length, "entries")
    }
}
