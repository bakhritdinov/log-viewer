pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore
import LogViewer.App
import LogViewer.Ui

// Desktop design: top bar, search, fields | results | details, status bar.
// Focus (context/trace) and live tail temporarily replace the results.
ApplicationWindow {
    id: window

    readonly property bool focusMode: Session.focus.active
    readonly property bool liveMode: Session.live.running && !focusMode
    readonly property bool mainMode: !focusMode && !liveMode

    // The entry shown in the details panel and where it comes from.
    readonly property var detailsModel: focusMode ? Session.focus.logs : liveMode ? Session.live.logs : Session.logs
    readonly property int detailsRow: focusMode ? focusView.selectedRow : liveMode ? liveView.selectedRow : Session.selectedRow
    readonly property bool detailsOpen: detailsRow >= 0
    readonly property var detailsEntry: mainMode ? Session.selectedEntry
                                                 : (detailsOpen ? Session.detailsOf(detailsModel, detailsRow) : Session.selectedEntry)

    function closeDetails() {
        if (focusMode) focusView.selectedRow = -1
        else if (liveMode) liveView.selectedRow = -1
        else Session.clearSelection()
    }
    function handleError(action, error) {
        switch (action) {
        case ErrorInfo.Retry: Session.retry(); break
        case ErrorInfo.OpenSettings: settings.openSection(0); break
        case ErrorInfo.NarrowRange: Session.narrowRange(); break
        case ErrorInfo.CopyCorsHint: clipboard.copy(Session.corsHint()); break
        case ErrorInfo.CopyDetails: clipboard.copy(error.detail); break
        case ErrorInfo.EditQuery: searchBar.focusSearch(); break
        }
    }

    readonly property var shortcutList: [
        { keys: [refreshShortcut.nativeText], text: qsTr("Refresh") },
        { keys: [findShortcut.nativeText], text: qsTr("Search") },
        { keys: [sourceShortcut.nativeText], text: qsTr("Choose the source") },
        { keys: [timeShortcut.nativeText], text: qsTr("Choose the period") },
        { keys: ["[", "]"], text: qsTr("Newer / older page") },
        { keys: ["Shift+[", "Shift+]"], text: qsTr("First / last page") },
        { keys: ["↑", "↓"], text: qsTr("Previous / next entry") },
        { keys: ["Esc"], text: qsTr("Close the details or the focus") },
        { keys: [saveShortcut.nativeText], text: qsTr("Save the query") },
        { keys: [qsTr("Ctrl+1…9")], text: qsTr("Run a saved query") },
        { keys: [shareShortcut.nativeText], text: qsTr("Share a link") },
        { keys: [qsTr("Space")], text: qsTr("Pause / resume live tail") },
        { keys: [settingsShortcut.nativeText], text: qsTr("Settings") },
        { keys: ["?"], text: qsTr("All keyboard shortcuts") },
    ]

    width: 1440
    height: 900
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    title: Session.namespaceName !== "" ? "%1 / %2 — LogViewer".arg(Session.namespaceName).arg(Session.app) : "LogViewer"
    color: Theme.bg
    font.family: Theme.sans

    Settings {
        id: prefs
        category: "ui.desktop"
        property bool dark: true
        property bool prettyJson: true
        property bool fieldsOpen: true
        property bool histogramOpen: true
        property real detailsWidth: 420
        property alias windowWidth: window.width
        property alias windowHeight: window.height
    }
    Binding { target: Theme; property: "dark"; value: prefs.dark }

    Clipboard { id: clipboard }

    // ── Shortcuts ──
    Shortcut { id: refreshShortcut; sequences: [StandardKey.Refresh, "Ctrl+R"]; enabled: window.mainMode; onActivated: Session.search() }
    Shortcut { id: findShortcut; sequence: "Ctrl+F"; enabled: !window.focusMode; onActivated: searchBar.focusSearch() }
    Shortcut { id: sourceShortcut; sequence: "Ctrl+K"; onActivated: topBar.openSourcePicker() }
    Shortcut { id: timeShortcut; sequence: "Ctrl+T"; enabled: window.mainMode; onActivated: topBar.openTimePicker() }
    Shortcut { id: saveShortcut; sequence: "Ctrl+S"; enabled: window.mainMode; onActivated: searchBar.openSaving() }
    Shortcut { id: shareShortcut; sequence: "Ctrl+L"; enabled: window.mainMode; onActivated: topBar.openShare() }
    Shortcut { id: settingsShortcut; sequences: [StandardKey.Preferences, "Ctrl+,"]; onActivated: settings.openSection(0) }
    Shortcut { sequence: "?"; onActivated: settings.openSection(3) }
    Shortcut { sequence: "["; enabled: window.mainMode; onActivated: Session.logs.goToPage(Session.logs.page - 1) }
    Shortcut { sequence: "]"; enabled: window.mainMode; onActivated: Session.logs.goToPage(Session.logs.page + 1) }
    Shortcut { sequence: "{"; enabled: window.mainMode; onActivated: Session.logs.goToPage(0) }
    Shortcut { sequence: "}"; enabled: window.mainMode; onActivated: Session.logs.goToPage(Session.logs.pageCount - 1) }
    Shortcut { sequence: "Space"; enabled: window.liveMode; onActivated: Session.live.paused = !Session.live.paused }
    Shortcut {
        sequence: "Esc"
        enabled: window.detailsOpen || window.focusMode
        onActivated: window.detailsOpen ? window.closeDetails() : Session.focus.close()
    }
    Instantiator {
        model: 9
        delegate: Shortcut {
            required property int index
            sequence: "Ctrl+" + (savedShortcut.index + 1)
            id: savedShortcut
            enabled: window.mainMode && savedShortcut.index < Session.savedQueries.count
            onActivated: Session.runSavedQuery(Session.savedQueries.get(savedShortcut.index).id)
        }
    }

    Connections {
        target: Session
        function onLinkEnvironmentMissing(name) {
            toast.show(qsTr("The link points to the environment “%1”, which is not set up here.").arg(name))
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            id: topBar
            Layout.fillWidth: true
            onSettingsRequested: settings.openSection(0)
            onThemeToggled: prefs.dark = !prefs.dark
        }

        LinkBanner {
            Layout.fillWidth: true
            visible: Session.openedFromLink && window.mainMode
            onSaveRequested: searchBar.openSaving()
        }

        SearchBar {
            id: searchBar
            Layout.fillWidth: true
            visible: !window.focusMode && !Session.needsSetup
            showViewSwitch: window.mainMode
            findShortcut: findShortcut.nativeText
            // The placeholder already explains the syntax; live mode says what the filter does.
            hint: window.liveMode ? qsTr("The filter applies to the stream on the fly") : ""
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            FieldsPanel {
                Layout.fillHeight: true
                visible: window.mainMode && !Session.needsSetup
                expanded: prefs.fieldsOpen
                onExpandedChanged: prefs.fieldsOpen = expanded
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                ErrorBanner {
                    Layout.fillWidth: true
                    visible: active && window.mainMode && !Session.needsSetup
                    error: Session.error
                    onActionTriggered: action => window.handleError(action, Session.error)
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: window.focusMode ? 2 : window.liveMode ? 3 : Session.patternsEnabled ? 1 : 0
                    // Stale results stay visible but dimmed under an error.
                    opacity: Session.hasError && !Session.needsSetup && window.mainMode ? 0.55 : 1

                    ResultsView {
                        histogramExpanded: prefs.histogramOpen
                        onHistogramExpandedChanged: prefs.histogramOpen = histogramExpanded
                        onSettingsRequested: settings.openSection(0)
                    }
                    PatternsView { }
                    FocusView { id: focusView }
                    LiveView { id: liveView }
                }
            }

            DetailsPanel {
                Layout.fillHeight: true
                Layout.preferredWidth: prefs.detailsWidth
                visible: window.detailsOpen && window.detailsEntry.valid
                entry: window.detailsEntry
                prettyJson: prefs.prettyJson
                navigable: window.mainMode
                onPreviousRequested: Session.selectPrevious()
                onNextRequested: Session.selectNext()
                onCloseRequested: window.closeDetails()
                onContextRequested: Session.focus.openContext(window.detailsModel, window.detailsRow, 60)
                onTraceRequested: Session.focus.openTrace(window.detailsModel, window.detailsRow)
                onResizeRequested: w => prefs.detailsWidth = Math.round(Math.max(360, Math.min(window.width * 0.6, w)))
            }
        }

        StatusBar {
            Layout.fillWidth: true
            hints: [
                { keys: [refreshShortcut.nativeText], text: qsTr("refresh") },
                { keys: [findShortcut.nativeText], text: qsTr("search") },
                { keys: [sourceShortcut.nativeText], text: qsTr("source") },
                { keys: ["[", "]"], text: qsTr("pages") },
                { keys: ["?"], text: qsTr("all keys") },
            ]
        }
    }

    SettingsDialog {
        id: settings
        darkTheme: prefs.dark
        prettyJson: prefs.prettyJson
        onDarkThemeChanged: prefs.dark = darkTheme
        onPrettyJsonChanged: prefs.prettyJson = prettyJson
        shortcuts: window.shortcutList
    }

    // Short notices that need no action.
    Popup {
        id: toast
        function show(text) { toastText.text = text; open(); toastTimer.restart() }
        parent: Overlay.overlay
        x: (parent.width - width) / 2
        y: parent.height - height - 48
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Surface { elevated: true }
        contentItem: Text {
            id: toastText
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textStrong
            Accessible.role: Accessible.AlertMessage
        }
        Timer { id: toastTimer; interval: 5000; onTriggered: toast.close() }
    }
}
