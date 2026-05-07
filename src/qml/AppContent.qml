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
    property bool isLoadingMore: false
    property bool hasMore: true
    property int lastCount: 0
    property var sessionStartTime: new Date()

    onCurrentNamespaceChanged: if(currentNamespace) refreshLogs(header.searchText)
    onCurrentAppChanged: if(currentApp) refreshLogs(header.searchText)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SearchHeader {
            id: header
            Layout.fillWidth: true
            onSearchTriggered: (query) => root.refreshLogs(query)
            onSearchTextChanged: (text) => {
                if (text === "") root.refreshLogs("")
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
                    onRowSelected: (data) => detailsArea.setEntry(data)
                    onTraceRequested: (traceId) => {
                        header.searchText = `trace_id: "${traceId}"`
                        root.refreshLogs(header.searchText)
                    }
                    onLoadMoreRequested: if (typeof logModel !== "undefined" && logModel !== null && !logModel.loading && root.hasMore) root.loadMore()
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
        function onLogsReceived(logs, isAppend) {
            if (isAppend) {
                if (typeof logModel !== "undefined" && logModel !== null) {
                    if (logs.length === 0 || logModel.count === root.lastCount) {
                        root.hasMore = false
                        console.log(">>> No NEW logs found. Stopping pagination to prevent loops.")
                    }
                }
            }
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

    function refreshLogs(query) {
        if (!root.currentNamespace || !root.currentApp) return;
        if (typeof configManager === "undefined" || configManager === null || typeof grafanaClient === "undefined" || grafanaClient === null || typeof logModel === "undefined" || logModel === null) return;
        
        root.sessionStartTime = new Date() 
        root.hasMore = true
        root.lastCount = 0
        logModel.clear()
        
        // Base stream selector using discovered labels
        let labels = `${root.nsLabelName}="${root.currentNamespace}", ${root.appLabelName}="${root.currentApp}"`
        let pipeline = ""
        
        if (query && query !== "*" && query.trim() !== "") {
            let parts = query.split(/ AND /i)
            parts.forEach(p => {
                p = p.trim()
                if (p.indexOf(":") !== -1) {
                    let kv = p.split(":")
                    let key = kv[0].trim()
                    let val = kv.slice(1).join(":").replace(/"/g, "").trim()

                    // VictoriaLogs LogsQL field filter: `field:"value"`, joined by whitespace.
                    pipeline += ` ${key}:"${root._escapeLogsQL(val)}"`
                } else {
                    // LogsQL case-insensitive regex phrase search.
                    pipeline += ` ~"(?i)${root._escapeLogsQL(p)}"`
                }
            })
        }

        let finalQuery = `{${labels}}${pipeline}`
        console.log(">>> FINAL LOGSQL:", finalQuery)

        let from = "now-1h", to = "now"
        if (header.timeRange === "Custom") {
            from = header.customFrom || "now-1h"
            to = header.customTo || "now"
        } else {
            from = `now-${header.timeRange}`
        }

        grafanaClient.queryLogs(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password(), finalQuery, from, to, false)
    }

    function loadMore() {
        if (typeof configManager === "undefined" || configManager === null || typeof grafanaClient === "undefined" || grafanaClient === null || typeof logModel === "undefined" || logModel === null) return;
        if (!root.currentNamespace || !root.currentApp || logModel.count === 0 || logModel.loading || !root.hasMore) return;
        
        let oldest = logModel.oldestTimestamp()
        if (oldest <= 0) return;

        let limitFrom = 0
        if (header.timeRange === "Custom") {
            if (header.customFrom) {
                let d = new Date(header.customFrom)
                if (!isNaN(d.getTime())) limitFrom = d.getTime()
            }
        } else {
            let matches = header.timeRange.match(/(\d+)([smhd])/)
            if (matches) {
                let val = parseInt(matches[1])
                let unit = matches[2]
                let ms = val * 1000
                if (unit === "m") ms *= 60
                else if (unit === "h") ms *= 3600
                else if (unit === "d") ms *= 86400
                limitFrom = root.sessionStartTime.getTime() - ms
            }
        }

        if (limitFrom > 0 && oldest <= (limitFrom + 1000)) {
            root.hasMore = false
            return;
        }

        let labels = `${root.nsLabelName}="${root.currentNamespace}", ${root.appLabelName}="${root.currentApp}"`
        let pipeline = ""

        // VictoriaLogs Grafana plugin ignores the outer `to` parameter (always treats it as "now"),
        // so pagination must be expressed inside LogsQL via the native `_time:Xs offset Ys` filter.
        // X = window width, Y = seconds the window's right edge sits behind "now".
        let nowMs = Date.now()
        let offsetSec = Math.max(1, Math.ceil((nowMs - oldest) / 1000))
        let strideSec = 600 // 10 min stride per batch
        if (limitFrom > 0) {
            let remainingSec = Math.floor((oldest - limitFrom) / 1000)
            if (remainingSec <= 0) { root.hasMore = false; return; }
            if (strideSec > remainingSec) strideSec = remainingSec
        }
        pipeline += ` _time:${strideSec}s offset ${offsetSec}s`

        let query = header.searchText
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
        console.log(">>> LOAD MORE LOGSQL:", finalQuery)

        // Outer time range mirrors the user's selector — actual upper bound is enforced by the _time filter above.
        let from = "now-1h", to = "now"
        if (header.timeRange === "Custom") {
            from = header.customFrom || "now-1h"
            to = header.customTo || "now"
        } else {
            from = `now-${header.timeRange}`
        }

        root.lastCount = logModel.count
        grafanaClient.queryLogs(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password(), finalQuery, from, to, true)
    }
}
