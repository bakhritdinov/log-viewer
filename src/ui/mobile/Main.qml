pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Mobile design: one column, bottom navigation (Logs · Chart · Settings),
// sheets from the bottom, a snackbar above the navigation. On desktop it runs
// in a phone-sized window for development.
ApplicationWindow {
    id: window

    // 0 logs, 1 chart, 2 settings.
    property int section: 0

    // A short notice above the navigation, optionally with one action ("Undo").
    function notify(text, actionText, action) { snackbar.show(text, actionText ?? "", action ?? null) }

    width: 390
    height: 844
    minimumWidth: 320
    minimumHeight: 560
    visible: true
    title: "LogViewer"
    color: Theme.bg
    font.family: Theme.sans

    // "system" follows the OS colour scheme as it changes.
    Binding {
        target: Theme; property: "dark"
        value: Session.prefs.theme === "system" ? Application.styleHints.colorScheme !== Qt.ColorScheme.Light
                                                : Session.prefs.theme === "dark"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: window.section
            LogsPage {
                id: logsPage
                onChartRequested: window.section = 1
                onSettingsRequested: window.section = 2
                onNotice: text => window.notify(text)
                onSearchRequested: searchScreen.open()
                onSourceRequested: sourceSheet.open()
                onEnvironmentRequested: environmentSheet.open()
                onPeriodRequested: timeSheet.open()
                onEntryRequested: row => details.show(Session.logs, row)
                onLiveEntryRequested: row => details.show(Session.live.logs, row)
                onPatternSortRequested: patternSortSheet.open()
                onSaveRequested: saveSheet.openSaving()
                onAddEnvironmentRequested: name => { missingEnvironment = ""; window.section = 2; settingsPage.openEnvironment("", name) }
            }
            ChartPage {
                onShowEntriesRequested: window.section = 0
                onSettingsRequested: window.section = 2
            }
            SettingsPage {
                id: settingsPage
                onNotice: text => window.notify(text)
            }
        }

        BottomNav {
            id: nav
            Layout.fillWidth: true
            current: window.section
            // "!" on Settings: nothing is connected yet, or the connection fails.
            settingsAlert: Session.needsSetup || (Session.hasError && Session.error.kind === ErrorInfo.Unreachable)
            onPicked: index => {
                if (index === window.section && index === 0) logsPage.scrollToTop()   // second tap: to the top
                if (index === window.section && index === 2) settingsPage.popToRoot()
                window.section = index
            }
        }
    }

    // A share link whose environment is not set up here.
    Connections {
        target: Session
        function onLinkEnvironmentMissing(name) { logsPage.missingEnvironment = name }
        function onEnvironmentChanged() { logsPage.missingEnvironment = "" }
    }

    SearchScreen {
        id: searchScreen
        onSaveRequested: saveSheet.openSaving()
        onShareRequested: shareSheet.open()
        onSavedQueryMenuRequested: id => savedSheet.openFor(id)
    }
    SaveQuerySheet { id: saveSheet; onNotice: (text, actionText, action) => window.notify(text, actionText, action) }
    SavedQuerySheet {
        id: savedSheet
        onNotice: (text, actionText, action) => window.notify(text, actionText, action)
        onRan: searchScreen.close()
        onRenameRequested: id => saveSheet.openRenaming(id)
    }
    // An entry, the view around it, and an entry of that view.
    function backToFeed() {
        focusDetails.close()
        if (Session.focus.active) Session.focus.close()
        focusScreen.close()
        details.close()
        window.section = 0
    }
    DetailsScreen {
        id: details
        onNotice: (text, actionText, action) => window.notify(text, actionText, action)
        onContextRequested: (model, row) => { Session.focus.openContext(model, row, 60); focusScreen.open() }
        onTraceRequested: (model, row) => { Session.focus.openTrace(model, row); focusScreen.open() }
        onFieldMenuRequested: (key, value) => fieldSheet.openFor(key, value)
        onFiltered: window.backToFeed()
        onClosed: logsPage.resumeLiveAfterEntry()
    }
    PatternSortSheet { id: patternSortSheet }
    FocusScreen {
        id: focusScreen
        onEntryRequested: row => focusDetails.show(Session.focus.logs, row)
        onSearchOpened: { focusDetails.close(); details.close(); window.section = 0 }
    }
    DetailsScreen {
        id: focusDetails
        backLabel: qsTr("Around")
        canOpenFocus: false
        onNotice: (text, actionText, action) => window.notify(text, actionText, action)
        onFieldMenuRequested: (key, value) => fieldSheet.openFor(key, value)
        onFiltered: window.backToFeed()
    }
    FieldSheet {
        id: fieldSheet
        onNotice: (text, actionText, action) => window.notify(text, actionText, action)
        onFiltered: window.backToFeed()
    }
    SourceSheet {
        id: sourceSheet
        onSettingsRequested: window.section = 2
        onAddEnvironmentRequested: { window.section = 2; settingsPage.openEnvironment("", "") }
    }
    TimeSheet { id: timeSheet }
    EnvironmentSheet {
        id: environmentSheet
        onSettingsRequested: window.section = 2
        onSourceMissing: sourceSheet.open()
    }
    ShareSheet { id: shareSheet; onNotice: (text, actionText, action) => window.notify(text, actionText, action) }

    // In the overlay, so it shows over the search screen and the sheets too.
    Snackbar {
        id: snackbar
        parent: Overlay.overlay
        z: 1000
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: nav.height + 12
        width: parent.width - 24
    }
}
