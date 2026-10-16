import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// One search field (Enter runs it) with save/history, the active conditions
// as removable chips, and the Records / Patterns switch.
Rectangle {
    id: root

    property bool showViewSwitch: true
    property bool liveMode: false       // a stream filter: no saving, history or chips
    property string hint
    property string findShortcut
    property string saveShortcut
    property string refreshShortcut

    function focusSearch() { searchBox.focusInput() }
    function openSaving() { savedPopup.openSaving() }

    implicitHeight: column.implicitHeight + 18
    color: Theme.bg

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.borderMuted
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 16
        anchors.topMargin: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            SearchBox {
                id: searchBox
                Layout.fillWidth: true
                text: Session.searchText
                onTextChanged: if (text !== Session.searchText) Session.searchText = text
                suggestions: Session.suggestions
                history: Session.history
                historyLabels: Session.historyLabels
                invalid: Session.searchError !== ""
                onSubmitted: Session.search()
                onSuggestionActivated: (index, exclude) => Session.applySuggestion(index, exclude)
                onHistoryActivated: text => { Session.searchText = text; Session.search() }
            }
            Text {
                Layout.leftMargin: 8
                visible: root.hint !== ""
                text: root.hint
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            IconButton {
                id: starButton
                visible: !root.liveMode
                iconName: "star"
                label: qsTr("Save query")
                shortcut: root.saveShortcut
                iconColor: Theme.warnText
                showTooltip: !savedPopup.opened         // the hint would cover the open popup
                onClicked: savedPopup.opened && savedPopup.tab === 0 ? savedPopup.close() : savedPopup.openSaving()
            }
            IconButton {
                id: historyButton
                visible: !root.liveMode
                iconName: "history"
                label: qsTr("Recent searches")
                showTooltip: !savedPopup.opened
                onClicked: savedPopup.opened && savedPopup.tab === 1 ? savedPopup.close() : savedPopup.openRecent()

                SavedQueriesPopup {
                    id: savedPopup
                    y: historyButton.height + 4
                    x: historyButton.width - width
                }
            }
            // "Enter" while the text differs from the search that ran.
            Kbd {
                visible: root.findShortcut !== "" && !root.liveMode
                text: Session.searchText !== Session.appliedSearchText ? "Enter" : root.findShortcut
            }
            // Refresh at the end of the search, as in 2.x (live tail has its own controls).
            RefreshControls {
                Layout.leftMargin: 8
                visible: !root.liveMode
                refreshKey: root.refreshShortcut
            }
        }

        // Why the search was not run.
        RowLayout {
            Layout.fillWidth: true
            visible: Session.searchError !== ""
            spacing: 6
            Icon { name: "warning"; size: 13; color: Theme.dangerText }
            Text {
                text: Session.searchError
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.dangerText
            }
            AppButton {
                // An odd number of unescaped quotes: offer to close the last one.
                visible: (Session.searchText.replace(/\\./g, "").match(/"/g) || []).length % 2 === 1
                variant: "link"
                implicitHeight: 22
                text: qsTr("Close the quote")
                onClicked: { Session.searchText = Session.searchText + "\""; Session.search() }
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: (Session.chips.count > 0 || root.showViewSwitch) && !root.liveMode
            Text {
                visible: Session.chips.count > 0
                text: qsTr("Filters")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            FilterChipBar {
                Layout.fillWidth: Session.chips.count > 0
                model: Session.chips
                onRemoveRequested: index => Session.removeChip(index)
            }
            AppButton {
                visible: Session.chips.count > 0
                variant: "link"
                text: qsTr("Clear all")
                onClicked: Session.clearSearch()
            }
            Item { Layout.fillWidth: true; visible: Session.chips.count === 0 }
            SegmentedControl {
                visible: root.showViewSwitch
                accessibleName: qsTr("Results view")
                model: [
                    // "…": the counts still grow while loading.
                    { label: qsTr("Records %1").arg(Session.logs.loadedCount.toLocaleString(Qt.locale(), "f", 0) + (Session.loading ? "…" : "")), value: false },
                    { label: Session.loading ? qsTr("Patterns %1").arg("…")
                           : Session.patterns.count > 0 ? qsTr("Patterns %1").arg(Session.patterns.count) : qsTr("Patterns"), value: true },
                ]
                value: Session.patternsEnabled
                onActivated: v => Session.patternsEnabled = v
            }
        }
    }
}
