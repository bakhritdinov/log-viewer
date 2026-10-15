import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// One search field (Enter runs it) with save/history, the active conditions
// as removable chips, and the Records / Patterns switch.
Rectangle {
    id: root

    property bool showViewSwitch: true
    property string hint
    property string findShortcut

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
                iconName: "star"
                label: qsTr("Save query")
                iconColor: Theme.warnText
                onClicked: savedPopup.openSaving()
            }
            IconButton {
                id: historyButton
                iconName: "history"
                label: qsTr("History and saved queries")
                onClicked: savedPopup.openBrowsing()

                SavedQueriesPopup {
                    id: savedPopup
                    y: historyButton.height + 4
                    x: historyButton.width - width
                }
            }
            Kbd { visible: root.findShortcut !== ""; text: root.findShortcut }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Session.chips.count > 0 || root.showViewSwitch
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
                    { label: qsTr("Records %1").arg(Session.logs.loadedCount.toLocaleString(Qt.locale(), "f", 0)), value: false },
                    { label: Session.patterns.count > 0 ? qsTr("Patterns %1").arg(Session.patterns.count) : qsTr("Patterns"), value: true },
                ]
                value: Session.patternsEnabled
                onActivated: v => Session.patternsEnabled = v
            }
        }
    }
}
