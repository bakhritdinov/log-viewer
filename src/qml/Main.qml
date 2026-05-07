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
        window: Theme.bg
        windowText: Theme.text
        base: Theme.bgRaised
        text: Theme.text
        button: Theme.bgSubtle
        buttonText: Theme.text
        highlight: Theme.successDim
        highlightedText: Theme.textOnAccent
    }

    background: Rectangle {
        color: Theme.bg
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
        height: 30
        background: Rectangle { color: Theme.bgInput }
        RowLayout {
            id: statusRow
            anchors.fill: parent
            anchors.leftMargin: Theme.sp4
            anchors.rightMargin: Theme.sp4
            spacing: Theme.sp2

            readonly property bool isLoading: typeof logModel !== "undefined" && logModel !== null && logModel.loading

            Rectangle {
                width: 8; height: 8; radius: 4
                color: statusRow.isLoading ? Theme.warnDim : Theme.success
                SequentialAnimation on opacity {
                    running: statusRow.isLoading
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                }
            }
            Label {
                text: statusRow.isLoading
                    ? "Loading…"
                    : "Connected · " + (typeof configManager !== "undefined" && configManager !== null ? configManager.currentEnv : "Unknown")
                font.pixelSize: Theme.fsSm
                color: statusRow.isLoading ? Theme.warnDim : Theme.success
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "v" + (typeof appVersion !== "undefined" ? appVersion : "")
                font.pixelSize: Theme.fsSm
                font.family: "Monospace"
                color: Theme.textMuted
            }
        }
    }

    Component.onCompleted: {
        if (typeof configManager !== "undefined" && configManager !== null) {
            Theme.dark = configManager.darkTheme
            if (configManager.url() && typeof grafanaClient !== "undefined" && grafanaClient !== null) {
                grafanaClient.fetchMappings(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password())
            }
        }
    }

    // Persist theme toggles back to QSettings via ConfigManager.
    Connections {
        target: Theme
        function onDarkChanged() {
            if (typeof configManager !== "undefined" && configManager !== null) {
                configManager.darkTheme = Theme.dark
            }
        }
    }
}
