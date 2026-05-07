import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: root
    color: "#0d1117"
    
    // Properties moved from Main.qml
    property alias searchHeader: header
    property string currentNamespace: ""
    property string currentApp: ""
    property string nsLabelName: "_namespace"
    property string appLabelName: "_appName"

    // Page-based pagination. Page 0 = newest window. Each step shifts the window
    // `pageWindowSec` seconds further into the past via LogsQL `_time:Xs offset Ys`.
    property int currentPage: 0
    readonly property int pageWindowSec: 600 // 10 minutes per page

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
    readonly property int maxPage: Math.max(1, Math.ceil(timeRangeSec / pageWindowSec))

    onCurrentNamespaceChanged: if(currentNamespace) { currentPage = 0; refreshLogs(header.searchText) }
    onCurrentAppChanged: if(currentApp) { currentPage = 0; refreshLogs(header.searchText) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SearchHeader {
            id: header
            Layout.fillWidth: true
            onSearchTriggered: (query) => { root.currentPage = 0; root.refreshLogs(query) }
            onSearchTextChanged: (text) => {
                if (text === "") { root.currentPage = 0; root.refreshLogs("") }
            }
            onNamespaceChanged: (ns) => {
                root.currentNamespace = ns
            }
            onAppChanged: (app) => {
                root.currentApp = app
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            Sidebar {
                id: sidebar
                SplitView.preferredWidth: sidebar.expandedField !== "" ? root.width * 0.5 : 280
                SplitView.minimumWidth: 200
                
                Behavior on SplitView.preferredWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }
            }

            SplitView {
                orientation: Qt.Vertical
                SplitView.fillWidth: true

                LogTableView {
                    id: tableView
                    SplitView.preferredHeight: root.height * 0.7
                    currentPage: root.currentPage
                    maxPage: root.maxPage
                    onRowSelected: (data) => detailsArea.setEntry(data)
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

                DetailsArea {
                    id: detailsArea
                    SplitView.fillHeight: true
                }
            }
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
        title: "❌ Network Error"
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        modal: true
        background: Rectangle { color: "#161b22"; border.color: "#f85149"; radius: 8 }
        Label {
            text: errorDialog.text
            color: "#f85149"
            padding: 20
            font.bold: true
            wrapMode: Text.Wrap
            width: 300
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

        // Page 0 = newest window (no offset). Subsequent pages shift `pageWindowSec` seconds further
        // into the past via LogsQL `_time:Xs offset Ys`, which the VictoriaLogs plugin honors.
        if (root.currentPage > 0) {
            pipeline += ` _time:${root.pageWindowSec}s offset ${root.currentPage * root.pageWindowSec}s`
        }

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

        grafanaClient.queryLogs(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password(), finalQuery, from, to)
    }
}
