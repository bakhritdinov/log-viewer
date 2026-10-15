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

    HistogramPanel {
        id: histogram
        Layout.fillWidth: true
        visible: !Session.needsSetup && !(root.empty && !Session.histogramFilterActive)
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: Session.needsSetup ? 0
                    : !root.empty ? 3
                    : Session.loading ? 1 : 2

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
                    spacing: 12
                    height: 28
                    SkeletonBar { width: 96 }
                    SkeletonBar { width: 40 }
                    SkeletonBar { width: 96 }
                    SkeletonBar { width: Math.max(80, (root.width - 300) * skeletonRow.modelData) }
                }
            }
        }

        // 2 — nothing found
        Item {
            EmptyState {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 420)
                iconName: "search"
                title: qsTr("No entries match")
                message: Session.namespaceName === ""
                         ? qsTr("Choose a namespace and an app.")
                         : qsTr("Nothing in %1 for the period “%2”.").arg(Session.app).arg(Session.timeRangeLabel)
                AppButton {
                    visible: Session.timeRangeKey !== "1d" && Session.timeRangeKey !== "2d" && Session.timeRangeKey !== "7d"
                    text: qsTr("Widen to 24 hours")
                    onClicked: Session.setPreset("1d")
                }
                AppButton {
                    visible: Session.histogramFilterActive
                    text: qsTr("Remove the %1 filter").arg(Session.histogramFilterLabel)
                    onClicked: Session.clearHistogramFilter()
                }
                AppButton {
                    visible: Session.chips.count > 0
                    text: qsTr("Clear the search")
                    onClicked: { Session.clearSearch(); Session.search() }
                }
            }
        }

        // 3 — results
        ColumnLayout {
            spacing: 0
            LogTable {
                id: table
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: Session.logs
                currentRow: Session.selectedRow
                highlightTerms: Session.searchTerms
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
        anchors.verticalCenter: parent.verticalCenter
        height: 10
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
