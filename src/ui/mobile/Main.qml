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

    // Built the first time it is needed and kept: building every screen and
    // sheet up front made the start seconds slower in the browser, and most are
    // never opened. get() builds it; item stays null until then.
    component Lazy: Loader {
        active: false
        function get() { active = true; return item }
        // A popup goes over the window, like one declared in it.
        onLoaded: if (item.hasOwnProperty("closePolicy")) item.parent = window.contentItem
    }
    onSectionChanged: {
        if (section === 1) chartPage.get()
        if (section === 2) settingsPage.get()
    }

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
                onSearchRequested: searchScreen.get().open()
                onSourceRequested: sourceSheet.get().open()
                onEnvironmentRequested: environmentSheet.get().open()
                onPeriodRequested: timeSheet.get().open()
                onEntryRequested: row => details.get().show(Session.logs, row)
                onLiveEntryRequested: row => details.get().show(Session.live.logs, row)
                onPatternSortRequested: patternSortSheet.get().open()
                onSaveRequested: saveSheet.get().openSaving()
                onAddEnvironmentRequested: name => { missingEnvironment = ""; window.section = 2; settingsPage.get().openEnvironment("", name) }
            }
            Lazy {
                id: chartPage
                sourceComponent: ChartPage {
                    onShowEntriesRequested: window.section = 0
                    onSettingsRequested: window.section = 2
                }
            }
            Lazy {
                id: settingsPage
                sourceComponent: SettingsPage {
                    onNotice: text => window.notify(text)
                }
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
                if (index === window.section && index === 2) settingsPage.item?.popToRoot()
                window.section = index
            }
        }
    }

    // A share link whose environment is not set up here; credentials the keychain refused.
    Connections {
        target: Session
        function onLinkEnvironmentMissing(name) { logsPage.missingEnvironment = name }
        function onEnvironmentChanged() { logsPage.missingEnvironment = "" }
        function onSecretsNotSaved(name) { window.notify(qsTr("The system keychain did not accept the credentials of %1").arg(name)) }
    }

    Lazy {
        id: searchScreen
        sourceComponent: SearchScreen {
            onSaveRequested: saveSheet.get().openSaving()
            onShareRequested: shareSheet.get().open()
            onSavedQueryMenuRequested: id => savedSheet.get().openFor(id)
        }
    }
    Lazy {
        id: saveSheet
        sourceComponent: SaveQuerySheet { onNotice: (text, actionText, action) => window.notify(text, actionText, action) }
    }
    Lazy {
        id: savedSheet
        sourceComponent: SavedQuerySheet {
            onNotice: (text, actionText, action) => window.notify(text, actionText, action)
            onRan: searchScreen.item?.close()
            onRenameRequested: id => saveSheet.get().openRenaming(id)
        }
    }
    // An entry, the view around it, and an entry of that view.
    function backToFeed() {
        focusDetails.item?.close()
        if (Session.focus.active) Session.focus.close()
        focusScreen.item?.close()
        details.item?.close()
        window.section = 0
    }
    Lazy {
        id: details
        sourceComponent: DetailsScreen {
            onNotice: (text, actionText, action) => window.notify(text, actionText, action)
            onContextRequested: (model, row) => { Session.focus.openContext(model, row, 60); focusScreen.get().open() }
            onTraceRequested: (model, row) => { Session.focus.openTrace(model, row); focusScreen.get().open() }
            onFieldMenuRequested: (key, value) => fieldSheet.get().openFor(key, value)
            onFiltered: window.backToFeed()
            onClosed: logsPage.resumeLiveAfterEntry()
        }
    }
    Lazy { id: patternSortSheet; sourceComponent: PatternSortSheet {} }
    Lazy {
        id: focusScreen
        sourceComponent: FocusScreen {
            onEntryRequested: row => focusDetails.get().show(Session.focus.logs, row)
            onSearchOpened: { focusDetails.item?.close(); details.item?.close(); window.section = 0 }
        }
    }
    Lazy {
        id: focusDetails
        sourceComponent: DetailsScreen {
            backLabel: qsTr("Around")
            canOpenFocus: false
            onNotice: (text, actionText, action) => window.notify(text, actionText, action)
            onFieldMenuRequested: (key, value) => fieldSheet.get().openFor(key, value)
            onFiltered: window.backToFeed()
        }
    }
    Lazy {
        id: fieldSheet
        sourceComponent: FieldSheet {
            onNotice: (text, actionText, action) => window.notify(text, actionText, action)
            onFiltered: window.backToFeed()
        }
    }
    Lazy {
        id: sourceSheet
        sourceComponent: SourceSheet {
            onSettingsRequested: window.section = 2
            onAddEnvironmentRequested: { window.section = 2; settingsPage.get().openEnvironment("", "") }
        }
    }
    Lazy { id: timeSheet; sourceComponent: TimeSheet {} }
    Lazy {
        id: environmentSheet
        sourceComponent: EnvironmentSheet {
            onSettingsRequested: window.section = 2
            onSourceMissing: sourceSheet.get().open()
        }
    }
    Lazy {
        id: shareSheet
        sourceComponent: ShareSheet { onNotice: (text, actionText, action) => window.notify(text, actionText, action) }
    }

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
