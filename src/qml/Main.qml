import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

ApplicationWindow {
    id: window
    visible: true
    width: 1200
    height: 800
    title: qsTr("LogViewer")

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
        color: window.palette.window
    }

    // Main designable content
    AppContent {
        id: mainContent
        anchors.fill: parent
    }

    // Helper functions for components to access mainContent
    function refreshLogs(query) { mainContent.refreshLogs(query) }
    function toggleFilter(key, value) { mainContent.toggleFilter(key, value) }
    property alias searchHeader: mainContent.searchHeader

    Shortcut {
        sequence: "F5"
        onActivated: mainContent.refreshLogs(mainContent.searchHeader.searchText)
    }

    Shortcut {
        sequence: StandardKey.Find
        onActivated: mainContent.searchHeader.focusSearch()
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            mainContent.searchHeader.searchText = ""
            mainContent.focusTable()
        }
    }

    footer: ToolBar {
        background: Rectangle { color: "#010409" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            Label {
                text: (typeof logModel !== "undefined" && logModel !== null && logModel.loading) ? "⌛ Loading..." : "● Connected (" + (typeof configManager !== "undefined" && configManager !== null ? configManager.currentEnv : "Unknown") + ")"
                font.pixelSize: 12
                color: (typeof logModel !== "undefined" && logModel !== null && logModel.loading) ? "#e3b341" : "#3fb950"
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "v" + (typeof appVersion !== "undefined" ? appVersion : "")
                font.pixelSize: 12
                color: "#8b949e"
            }
        }
    }

    Component.onCompleted: {
        if (typeof configManager !== "undefined" && configManager !== null && configManager.url()) {
            if (typeof grafanaClient !== "undefined" && grafanaClient !== null) {
                grafanaClient.fetchMappings(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password())
            }
        }
    }
}
