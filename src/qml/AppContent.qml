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

    // Page-based pagination. Page 0 = newest window. Each step shifts the window
    // `actualPageWindowSec` seconds further into the past via LogsQL `_time:Xs offset Ys`.
    property int currentPage: 0
    readonly property int pageWindowSec: 600 // 10 minutes per page (default)
    // Cap by user-selected timeRange so a single page is never wider than the range itself.
    readonly property int actualPageWindowSec: Math.min(pageWindowSec, Math.max(1, timeRangeSec))

    // Total seconds covered by the user's selected time range — used to cap how far pagination can walk.
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
    readonly property int maxPage: Math.max(1, Math.ceil(timeRangeSec / actualPageWindowSec))

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
        configManager.setLastSelection(currentNamespace, currentApp, header.timeRange)
    }

    Connections {
        target: header
        function onTimeRangeChanged() { root.persistSelection() }
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

            // Backdrop — click outside closes.
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: root.sidebarOpen ? 0.4 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.dBase } }
                MouseArea { anchors.fill: parent; onClicked: root.sidebarOpen = false }
            }

            // Sidebar drawer — slides in from the left.
            Sidebar {
                id: sidebar
                width: Math.min(360, root.width * 0.6)
                height: parent.height
                x: root.sidebarOpen ? 0 : -width
                Behavior on x { NumberAnimation { duration: Theme.dBase; easing.type: Easing.OutCubic } }
            }
        }
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
                    onClicked: { errorDialog.close(); root.refreshLogs(header.searchText) }
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
        refreshLogs(header.searchText)
    }

    function gotoPage(page) {
        if (page < 0) return
        if (root.currentPage === page) { refreshLogs(header.searchText); return }
        root.currentPage = page
        refreshLogs(header.searchText)
    }

    function refreshLogs(query) {
        if (!root.currentNamespace || !root.currentApp) return;
        if (typeof configManager === "undefined" || configManager === null || typeof grafanaClient === "undefined" || grafanaClient === null || typeof logModel === "undefined" || logModel === null) return;

        logModel.clear()

        let labels = `${root.nsLabelName}="${root.currentNamespace}", ${root.appLabelName}="${root.currentApp}"`
        let pipeline = ""

        // Every page (including 0) is anchored by `_time:Xs offset Ys` so windows don't overlap.
        // Page 0 takes the newest slice; subsequent pages walk backwards by `actualPageWindowSec`.
        pipeline += ` _time:${root.actualPageWindowSec}s offset ${root.currentPage * root.actualPageWindowSec}s`

        if (query && query !== "*" && query.trim() !== "") {
            let parts = query.split(/ AND /i)
            parts.forEach(p => {
                p = p.trim()
                if (p.indexOf(":") !== -1) {
                    let kv = p.split(":")
                    let key = kv[0].trim()
                    let val = kv.slice(1).join(":").replace(/"/g, "").trim()
                    pipeline += ` ${key}:"${root._escapeLogsQL(val)}"`
                } else {
                    pipeline += ` ~"(?i)${root._escapeLogsQL(p)}"`
                }
            })
        }

        let finalQuery = `{${labels}}${pipeline}`
        console.log(">>> FINAL LOGSQL:", finalQuery, "page:", root.currentPage)

        let from = "now-1h", to = "now"
        if (header.timeRange === "Custom") {
            from = header.customFrom || "now-1h"
            to = header.customTo || "now"
        } else {
            from = `now-${header.timeRange}`
        }

        grafanaClient.queryLogs(configManager.url(), configManager.token(), configManager.datasourceUid(), configManager.user(), configManager.password(), finalQuery, from, to)
    }
}
