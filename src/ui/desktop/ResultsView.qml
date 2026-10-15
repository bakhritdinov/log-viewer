pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The record view: first-run guide, skeleton while the first batch loads,
// "nothing found" with ways out, or histogram + table + paging.
ColumnLayout {
    id: root

    property alias histogramExpanded: histogram.expanded
    property alias table: table

    signal settingsRequested()

    readonly property bool empty: Session.logs.totalCount === 0

    spacing: 0

    // Thin progress line while loading.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 3
        color: Session.loading ? Theme.subtle : "transparent"
        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("Loading logs")
        Rectangle {
            id: runner
            visible: Session.loading
            width: parent.width / 3
            height: parent.height
            color: Theme.accent
            XAnimator on x {
                running: Session.loading
                loops: Animation.Infinite
                from: -runner.width
                to: root.width
                duration: 1200
            }
        }
    }

    // The skeleton waits 300 ms: a quick answer must not flash it.
    property bool skeletonDue: false
    readonly property bool firstBatch: Session.loading && root.empty
    onFirstBatchChanged: { skeletonDue = false; if (firstBatch) skeletonTimer.restart() }
    Timer { id: skeletonTimer; interval: 300; onTriggered: root.skeletonDue = root.firstBatch }

    signal sourceRequested()

    // A refresh over shown entries: the ones newer than the old top glow green
    // for 3 s (nothing jumps; the old rows stay where they were).
    property real previousTopMs: Infinity
    property string previousSource
    Connections {
        target: Session
        function onLoadingChanged() {
            if (Session.loading) {
                const top = Session.logs.totalCount > 0 ? Session.logs.rowData(0).timeMs : NaN
                const source = Session.namespaceName + "/" + Session.app
                root.previousTopMs = !isNaN(top) && source === root.previousSource ? top : Infinity
                root.previousSource = source
            } else if (root.previousTopMs !== Infinity) {
                freshTimer.restart()
            }
        }
    }
    Timer { id: freshTimer; interval: 3000; onTriggered: root.previousTopMs = Infinity }

    HistogramPanel {
        id: histogram
        Layout.fillWidth: true
        visible: !Session.needsSetup && !(root.empty && !Session.histogramFilterActive && !root.skeletonDue)
                 && !(Session.hasError && root.empty)
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: Session.needsSetup ? 0
                    : !root.empty ? 5
                    : Session.loading ? (root.skeletonDue ? 1 : 4)
                    : Session.hasError ? 3 : 2

        // 0 — first launch
        Item {
            EmptyState {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 440)
                iconName: "logs"
                title: qsTr("Connect to Grafana")
                message: qsTr("1. Enter the Grafana URL and the log datasource UID.\n2. Add a login with password or an API token.\n3. Press “Test connection” — namespaces and apps are found automatically.")
                AppButton {
                    variant: "primary"
                    text: qsTr("Open settings")
                    onClicked: root.settingsRequested()
                }
            }
        }

        // 1 — skeleton
        Column {
            topPadding: 6
            Repeater {
                model: [0.78, 0.62, 0.9, 0.55, 0.84, 0.7, 0.66, 0.88, 0.58, 0.74, 0.8, 0.6]
                delegate: Row {
                    id: skeletonRow
                    required property real modelData
                    leftPadding: 16
                    topPadding: 9                       // bars centred in the 28 px row
                    spacing: 12
                    height: 28
                    SkeletonBar { width: 96 }
                    SkeletonBar { width: 40 }
                    SkeletonBar { width: 96 }
                    SkeletonBar { width: Math.max(80, (root.width - 300) * skeletonRow.modelData) }
                }
            }
        }

        // 2 — nothing found: why, and the ways out that fit
        Item {
            id: nothing
            readonly property bool noSource: Session.namespaceName === ""
            readonly property bool byInterval: Session.histogramFilterActive
            readonly property bool bySearch: Session.chips.count > 0
            readonly property var lastChip: bySearch ? Session.chips.get(Session.chips.count - 1) : null
            readonly property bool wide: ["1d", "2d", "7d"].indexOf(Session.timeRangeKey) >= 0
            EmptyState {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 420)
                iconName: nothing.noSource ? "source" : "search"
                title: nothing.noSource ? qsTr("Choose a source")
                     : nothing.byInterval ? qsTr("Nothing in the picked interval")
                     : nothing.bySearch ? qsTr("No entries match")
                     : qsTr("No entries for “%1”").arg(Session.timeRangeLabel)
                message: nothing.noSource ? qsTr("Pick a namespace and an app to see their logs.")
                       : nothing.byInterval ? qsTr("%1 holds no entries of this level.").arg(Session.histogramFilterLabel)
                       : nothing.bySearch ? qsTr("For “%1” there are no entries in %2 matching %3.")
                                            .arg(Session.timeRangeLabel).arg(Session.app).arg(Session.searchText)
                       : qsTr("Nothing came from %1 during this period.").arg(Session.app)
                AppButton {
                    visible: nothing.noSource
                    variant: "primary"
                    text: qsTr("Choose a source")
                    onClicked: root.sourceRequested()
                }
                AppButton {
                    visible: !nothing.noSource && nothing.byInterval
                    text: qsTr("Show the whole period")
                    onClicked: Session.clearHistogramFilter()
                }
                AppButton {
                    visible: !nothing.noSource && !nothing.byInterval && !nothing.wide
                    text: qsTr("Widen to 24 hours")
                    onClicked: Session.setPreset("1d")
                }
                AppButton {
                    visible: !nothing.noSource && !nothing.byInterval && nothing.bySearch
                    text: nothing.lastChip ? qsTr("Remove %1").arg(nothing.lastChip.text) : ""
                    onClicked: Session.removeChip(Session.chips.count - 1)
                }
                AppButton {
                    visible: !nothing.noSource && !nothing.byInterval && Session.chips.count > 1
                    text: qsTr("Clear the search")
                    onClicked: Session.clearSearch()
                }
                AppButton {
                    visible: !nothing.noSource && !nothing.byInterval && !nothing.bySearch
                    text: qsTr("Turn on live tail")
                    onClicked: Session.live.start()
                }
            }
        }

        // 3 — the request failed and there is nothing to show (the banner explains)
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 8
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "logs"; size: 28; strokeWidth: 1.6; color: Theme.border }
                Text {
                    text: qsTr("No entries — the request failed")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    color: Theme.textDisabled
                }
            }
        }

        // 4 — the first 300 ms of a load: nothing yet
        Item { }

        // 5 — results
        ColumnLayout {
            spacing: 0
            LogTable {
                id: table
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: Session.logs
                currentRow: Session.selectedRow
                highlightTerms: Session.searchTerms
                newerThanMs: Session.loading ? Infinity : root.previousTopMs
                onRowClicked: row => Session.selectRow(row)
                onMoveRequested: delta => delta < 0 ? Session.selectPrevious() : Session.selectNext()
            }
        }
    }

    PageFooter {
        Layout.fillWidth: true
        visible: !Session.needsSetup
    }

    component SkeletonBar: Rectangle {
        implicitHeight: 10
        radius: Theme.radiusSm
        color: Theme.subtle
        SequentialAnimation on opacity {
            running: Session.loading
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { from: 0.45; to: 0.85; duration: 700 }
            NumberAnimation { from: 0.85; to: 0.45; duration: 700 }
        }
    }
}
