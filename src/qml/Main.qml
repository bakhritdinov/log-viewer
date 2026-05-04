import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import LogViewerApp

Controls.ApplicationWindow {
    id: root
    visible: true
    width: 1200
    height: 800
    title: qsTr("LogViewer")

    property alias searchHeader: header
    property string currentNamespace: ""
    property string currentApp: ""
    property bool isLoadingMore: false
    property bool hasMore: true
    property int lastCount: 0
    property var sessionStartTime: new Date()

    palette {
        window: "#0d1117"
        windowText: "#c9d1d9"
        base: "#161b22"
        text: "#c9d1d9"
        button: "#21262d"
        buttonText: "#c9d1d9"
        highlight: "#238636"
        highlightedText: "#ffffff"
    }

    background: Rectangle {
        color: root.palette.window
    }

    Shortcut {
        sequence: "F5"
        onActivated: root.refreshLogs(header.searchText)
    }

    Shortcut {
        sequence: StandardKey.Find
        onActivated: header.focusSearch()
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            header.searchText = ""
            tableView.focus = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SearchHeader {
            id: header
            Layout.fillWidth: true
            onSearchTriggered: (query) => root.refreshLogs(query)
            onNamespaceChanged: (ns) => { 
                root.currentNamespace = ns
                root.refreshLogs(header.searchText)
            }
            onAppChanged: (app) => {
                root.currentApp = app
                root.refreshLogs(header.searchText)
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
                    onLoadMoreRequested: if (!logModel.loading && root.hasMore) root.loadMore()
                }

                DetailsArea {
                    id: detailsArea
                    SplitView.fillHeight: true
                }
            }
        }
    }

    footer: Controls.ToolBar {
        background: Rectangle { color: "#010409" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            Controls.Label {
                text: logModel.loading ? "⌛ Loading..." : "● Connected (" + configManager.currentEnv + ")"
                font.pixelSize: 12
                color: logModel.loading ? "#e3b341" : "#3fb950"
            }
            Item { Layout.fillWidth: true }
            Controls.Label {
                text: "Total Logs: " + logModel.count
                font.pixelSize: 12
                color: "#8b949e"
            }
        }
    }

    Connections {
        target: grafanaClient
        function onLogsReceived(logs, isAppend) {
            if (isAppend) {
                if (logs.length === 0 || logModel.count === root.lastCount) {
                    root.hasMore = false
                    console.log(">>> No NEW logs found. Stopping pagination to prevent loops.")
                }
            }
        }
        function onErrorOccurred(error) {
            errorDialog.text = error
            errorDialog.open()
        }
    }

    Controls.Dialog {
        id: errorDialog
        property string text: ""
        title: "❌ Network Error"
        anchors.centerIn: parent
        standardButtons: Controls.Dialog.Ok
        modal: true
        background: Rectangle { color: "#161b22"; border.color: "#f85149"; radius: 8 }
        Controls.Label {
            text: errorDialog.text
            color: "#f85149"
            padding: 20
            font.bold: true
            wrapMode: Text.Wrap
            width: 300
        }
    }

    function refreshLogs(query) {
        if (!root.currentNamespace || !root.currentApp) return;
        root.sessionStartTime = new Date() 
        root.hasMore = true
        root.lastCount = 0
        logModel.clear()
        
        let finalQuery = `_stream: {_namespace="${root.currentNamespace}", _appName="${root.currentApp}"} `
        if (query && query !== "*") finalQuery += ` AND (${query})`

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
            console.log(">>> Reached limitFrom boundary. Stopping pagination.")
            root.hasMore = false
            return;
        }

        let finalQuery = `_stream: {_namespace="${root.currentNamespace}", _appName="${root.currentApp}"} `
        if (header.searchText && header.searchText !== "*") finalQuery += ` AND (${header.searchText})`

        let to = (oldest - 1).toString()
        let fromVal = oldest - 3600000 
        if (limitFrom > 0 && fromVal < limitFrom) fromVal = limitFrom
        
        let from = fromVal.toString()
        
        if (Number(to) <= Number(from)) {
             console.log(">>> 'to' <= 'from', window closed.")
             root.hasMore = false
             return;
        }

        console.log(">>> Requesting more: from", from, "to", to)
        root.lastCount = logModel.count
        grafanaClient.queryLogs(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password(), finalQuery, from, to, true)
    }

    Component.onCompleted: {
        if (configManager.url()) {
            grafanaClient.fetchMappings(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password())
        }
    }
}
