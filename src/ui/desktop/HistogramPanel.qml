pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Distribution over time: level totals (toggle a level), bucket step, the bars
// (click narrows the list) and the active narrowing as a removable chip.
Rectangle {
    id: root

    property bool expanded: true
    readonly property var steps: [
        { label: qsTr("Auto"), value: 0 },
        { label: qsTr("1 min"), value: 60000 },
        { label: qsTr("5 min"), value: 300000 },
        { label: qsTr("15 min"), value: 900000 },
        { label: qsTr("1 h"), value: 3600000 },
    ]

    // Bucket of the picked interval (dims the other bars), -1 when none.
    readonly property int selectedIndex: {
        const from = Session.histogramFilterFromMs
        if (from <= 0) return -1
        for (let i = 0; i < Session.histogram.count; ++i)
            if (Session.histogram.get(i).startMs === from) return i
        return -1
    }
    // WARN and above per bucket, for the one-line trend of the collapsed chart.
    readonly property var trend: {
        void Session.histogramMax                    // re-evaluated with the chart
        const out = []
        for (let i = 0; i < Session.histogram.count; ++i) out.push(Session.histogram.get(i).important)
        return out
    }
    // First batch on its way: grey bars instead of an empty frame.
    readonly property bool skeleton: Session.loading && Session.histogram.count === 0

    implicitHeight: column.implicitHeight + (expanded ? 18 : 12)
    color: Theme.bg
    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Distribution over time")

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.borderMuted }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 16
        anchors.topMargin: root.expanded ? 10 : 6
        spacing: 8

        // Two independent blocks: what is shown (label, levels, trend, narrowing)
        // on the left, how it is bucketed (step, collapse) on the right.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            // Wraps onto a second line when the details panel narrows the view.
            Flow {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 10
                Item {
                    implicitWidth: distributionLabel.implicitWidth
                    implicitHeight: Theme.chipHeight        // the height of every header control
                    SectionLabel { id: distributionLabel; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Distribution") }
                }
                LevelLegend {
                    id: legend
                    compact: true
                    totals: Session.levelTotals
                    activeLevel: Session.activeLevel
                    onToggled: level => Session.applyLevelFilter(level)
                }
                // Only a time bucket or a pattern needs a chip; a level shows on the
                // legend and is turned off there (or by double-clicking the chart).
                // Collapsed: the trend in one line (the level buttons still filter).
                Item {
                    visible: !root.expanded && root.trend.length > 0
                    implicitWidth: 160
                    implicitHeight: Theme.chipHeight
                    Sparkline {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 16
                        values: root.trend
                        maxValue: Math.max(1, Session.histogramMax)
                        color: Theme.warn
                        opacity: 0.8
                    }
                }
                FilterChip {
                    visible: Session.histogramRangeOrPatternFilter
                    pill: false
                    implicitHeight: Theme.chipHeight
                    text: Session.histogramFilterLabel
                    onRemoveRequested: Session.clearHistogramFilter()
                }
            }
            Row {
                Layout.alignment: Qt.AlignTop
                spacing: 6
                SegmentedControl {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.expanded
                    compact: true
                    accessibleName: qsTr("Histogram step")
                    model: root.steps
                    value: Session.manualBucketMs
                    onActivated: v => Session.manualBucketMs = v
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: Theme.chipHeight
                    implicitHeight: Theme.chipHeight
                    iconName: root.expanded ? "chevronUp" : "chevronDown"
                    label: root.expanded ? qsTr("Collapse the chart") : qsTr("Expand the chart")
                    onClicked: root.expanded = !root.expanded
                }
            }
        }

        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            visible: root.expanded && root.skeleton
            spacing: 2
            Repeater {
                model: 48
                delegate: Rectangle {
                    required property int index
                    anchors.bottom: parent ? parent.bottom : undefined
                    width: (parent.width - 47 * 2) / 48
                    height: 76 * (0.3 + 0.3 * Math.abs(Math.sin(index / 4)))
                    radius: 1
                    color: Theme.subtle
                    SequentialAnimation on opacity {
                        running: root.skeleton
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.45; to: 0.85; duration: 700 }
                        NumberAnimation { from: 0.85; to: 0.45; duration: 700 }
                    }
                }
            }
        }
        HistogramView {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            visible: root.expanded && !root.skeleton
            selectedIndex: root.selectedIndex
            model: Session.histogram
            maxTotal: Session.histogramMax
            // The bars draw WARN and ERROR: a click on a segment shows its level,
            // above the bar the level picked in the legend or both of them —
            // never the INFO of the interval (as on the phone).
            onBucketClicked: (index, level) => {
                const picked = level !== "" ? level : Session.activeLevel
                Session.applyBucketFilter(index, picked, picked === "")
            }
            onResetRequested: Session.clearHistogramFilter()
        }
        // Evenly spaced times; each label sits at its point of the time line
        // (the first and last flush with the edges).
        Item {
            id: axis
            Layout.fillWidth: true
            implicitHeight: Math.ceil(axisMetrics.height)
            visible: root.expanded && !root.skeleton
            FontMetrics { id: axisMetrics; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
            Repeater {
                model: Session.histogramAxis
                delegate: Text {
                    required property int index
                    required property string modelData
                    readonly property int last: Session.histogramAxis.length - 1
                    x: last <= 0 ? 0 : Math.max(0, Math.min(axis.width - implicitWidth, axis.width * index / last - implicitWidth / 2))
                    text: modelData
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    color: Theme.textMuted
                }
            }
        }
    }
}
