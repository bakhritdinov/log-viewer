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

    implicitHeight: column.implicitHeight + 18
    color: Theme.bg
    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Distribution over time")

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.borderMuted }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 16
        anchors.topMargin: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            // Wraps onto a second line when the details panel narrows the view.
            Flow {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 14
                Item {
                    implicitWidth: distributionLabel.implicitWidth
                    implicitHeight: 24
                    SectionLabel { id: distributionLabel; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Distribution") }
                }
                LevelLegend {
                    totals: Session.levelTotals
                    activeLevel: Session.activeLevel
                    onToggled: level => Session.applyLevelFilter(level)
                }
                FilterChip {
                    visible: Session.histogramFilterActive
                    text: Session.histogramFilterLabel
                    onRemoveRequested: Session.clearHistogramFilter()
                }
            }
            SegmentedControl {
                Layout.alignment: Qt.AlignTop
                visible: root.expanded
                accessibleName: qsTr("Histogram step")
                model: root.steps
                value: Session.manualBucketMs
                onActivated: v => Session.manualBucketMs = v
            }
            IconButton {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 24
                implicitHeight: 24
                iconName: root.expanded ? "chevronUp" : "chevronDown"
                label: root.expanded ? qsTr("Collapse the chart") : qsTr("Expand the chart")
                onClicked: root.expanded = !root.expanded
            }
        }

        HistogramView {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            visible: root.expanded
            model: Session.histogram
            maxTotal: Session.histogramMax
            onBucketClicked: (index, level) => Session.applyBucketFilter(index, level)
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.expanded
            Repeater {
                model: Session.histogramAxis
                delegate: Text {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: index === 0 ? Text.AlignLeft : (index === Session.histogramAxis.length - 1 ? Text.AlignRight : Text.AlignHCenter)
                    text: modelData
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    color: Theme.textMuted
                }
            }
        }
    }
}
