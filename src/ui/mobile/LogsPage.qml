pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The Logs section: where, the search with its chips, the distribution in one
// line (tap: Chart), Records / Patterns, and the feed of cards.
ColumnLayout {
    id: root

    signal chartRequested()
    signal settingsRequested()

    function scrollToTop() { feed.positionViewAtBeginning() }

    // WARN and above per bucket, for the one-line distribution.
    readonly property var trend: {
        void Session.histogramMax                    // re-evaluated with the chart
        const out = []
        for (let i = 0; i < Session.histogram.count; ++i) out.push(Session.histogram.get(i).important)
        return out
    }
    property real nowMs: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.nowMs = Date.now() }

    spacing: 0

    AppBar { Layout.fillWidth: true }

    // Search and the active conditions.
    Rectangle {
        Layout.fillWidth: true
        visible: !Session.needsSetup
        implicitHeight: searchColumn.implicitHeight + 18
        color: Theme.surface
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
        ColumnLayout {
            id: searchColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 2
            spacing: 8
            SearchBox {
                Layout.fillWidth: true
                touch: true
                placeholder: qsTr("Word, key:value…")
                text: Session.searchText
                onTextChanged: if (text !== Session.searchText) Session.searchText = text
                suggestions: Session.suggestions
                history: Session.history
                invalid: Session.searchError !== ""
                onSubmitted: Session.search()
                onSuggestionActivated: (index, exclude) => Session.applySuggestion(index, exclude)
                onHistoryActivated: text => { Session.searchText = text; Session.search() }
            }
            Text {
                Layout.fillWidth: true
                visible: Session.searchError !== ""
                text: Session.searchError
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.dangerText
            }
            // Period first, then the conditions; scrolls sideways, never wraps.
            Flickable {
                Layout.fillWidth: true
                implicitHeight: 32
                contentWidth: chipsRow.implicitWidth
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Row {
                    id: chipsRow
                    spacing: 6
                    AbstractButton {
                        id: periodChip
                        implicitHeight: 32
                        implicitWidth: periodRow.implicitWidth + 20
                        Accessible.name: qsTr("Period: %1").arg(Session.timeRangeLabel)
                        background: Rectangle {
                            radius: 16
                            color: periodChip.pressed ? Theme.hover : Theme.subtle
                            border.width: 1
                            border.color: Theme.border
                        }
                        contentItem: Item {
                            Row {
                                id: periodRow
                                anchors.centerIn: parent
                                spacing: 6
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: "clock"; size: 14; color: Theme.textStrong }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Session.timeRangeShortLabel
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontMd
                                    font.weight: Font.Medium
                                    color: Theme.textStrong
                                }
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronDown"; size: 12; color: Theme.textMuted }
                            }
                        }
                    }
                    FilterChipBar {
                        touch: true
                        model: Session.chips
                        onRemoveRequested: index => Session.removeChip(index)
                    }
                }
            }
        }
    }

    // WARN and ERROR over the period in one line; tap opens the chart.
    AbstractButton {
        Layout.fillWidth: true
        visible: !Session.needsSetup && root.trend.length > 0
        implicitHeight: 34
        Accessible.name: qsTr("WARN and ERROR over the period, open the chart")
        onClicked: root.chartRequested()
        contentItem: Sparkline {
            values: root.trend
            maxValue: Math.max(1, Session.histogramMax)
            color: Theme.warn
        }
        leftPadding: 12
        rightPadding: 12
        topPadding: 8
        bottomPadding: 4
        background: null
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 4
        Layout.bottomMargin: 8
        visible: !Session.needsSetup
        spacing: 8
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Results view")
            model: [
                { label: qsTr("Records · %1").arg(Session.logs.loadedCount.toLocaleString(Qt.locale(), "f", 0) + (Session.loading ? "…" : "")), value: false },
                { label: Session.patterns.count > 0 ? qsTr("Patterns · %1").arg(Session.patterns.count) : qsTr("Patterns"), value: true },
            ]
            value: Session.patternsEnabled
            onActivated: v => Session.patternsEnabled = v
        }
        AppButton {
            touch: true
            text: "Live"
            iconName: "play"
            onClicked: Session.live.start()
        }
    }

    ErrorBanner {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 8
        visible: active && !Session.needsSetup
        touch: true
        error: Session.error
        onActionTriggered: action => {
            if (action === ErrorInfo.Retry) Session.retry()
            else if (action === ErrorInfo.OpenSettings) root.settingsRequested()
            else if (action === ErrorInfo.NarrowRange) Session.narrowRange()
        }
    }

    SetupGuide {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Session.needsSetup
        onSettingsRequested: root.settingsRequested()
    }

    ListView {
        id: feed
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !Session.needsSetup
        leftMargin: 12
        rightMargin: 12
        bottomMargin: 12
        spacing: 8
        clip: true
        model: Session.logs
        boundsBehavior: Flickable.DragAndOvershootBounds
        Accessible.role: Accessible.List
        Accessible.name: qsTr("Logs")
        // One growing list: more of the loaded entries as the end comes near.
        onAtYEndChanged: if (atYEnd && Session.logs.canShowMore) Session.logs.showMore()
        Component.onCompleted: Session.logs.progressive = true
        delegate: LogCard {
            width: ListView.view.width - 24
            highlightTerms: Session.searchTerms
            nowMs: root.nowMs
            lines: Math.max(2, Session.prefs.messageLines)
        }
        footer: Item {
            width: ListView.view.width - 24
            height: Session.hasMore || Session.loading ? 64 : 0
            AppButton {
                anchors.centerIn: parent
                visible: Session.hasMore && !Session.loading
                touch: true
                text: qsTr("Load %1 more").arg(Session.loadStep.toLocaleString(Qt.locale(), "f", 0))
                onClicked: Session.loadMore()
            }
            Text {
                anchors.centerIn: parent
                visible: Session.loading
                text: qsTr("Loading…")
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textMuted
            }
        }
    }
}
