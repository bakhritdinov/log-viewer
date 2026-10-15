pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The Chart section: WARN/ERROR over the period, level totals (tap to filter)
// and the step. Tapping a bar narrows the feed to that interval.
ColumnLayout {
    id: root

    signal showEntriesRequested()

    readonly property var steps: [
        { label: qsTr("Auto"), value: 0 },
        { label: qsTr("1 min"), value: 60000 },
        { label: qsTr("5 min"), value: 300000 },
        { label: qsTr("1 h"), value: 3600000 },
    ]

    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 56
        color: Theme.surface
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 0
            Text {
                text: qsTr("Chart")
                font.family: Theme.sans
                font.pixelSize: Theme.fontXl + 2
                font.weight: Font.DemiBold
                color: Theme.textStrong
                Accessible.role: Accessible.Heading
            }
            Text {
                Layout.fillWidth: true
                text: Session.app !== "" ? "%1 · %2".arg(Session.app).arg(Session.timeRangeLabel) : Session.timeRangeLabel
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: body.implicitHeight + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: body
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 14

            LevelLegend {
                Layout.fillWidth: true
                touch: true
                totals: Session.levelTotals
                activeLevel: Session.activeLevel
                onToggled: level => { Session.applyLevelFilter(level); root.showEntriesRequested() }
            }
            HistogramView {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                model: Session.histogram
                maxTotal: Session.histogramMax
                showTooltip: false
                onBucketClicked: (index, level) => { Session.applyBucketFilter(index, level); root.showEntriesRequested() }
                onResetRequested: Session.clearHistogramFilter()
            }
            RowLayout {
                Layout.fillWidth: true
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
            SegmentedControl {
                Layout.fillWidth: true
                touch: true
                fill: true
                accessibleName: qsTr("Histogram step")
                model: root.steps
                value: Session.manualBucketMs
                onActivated: v => Session.manualBucketMs = v
            }
            FilterChip {
                visible: Session.histogramRangeOrPatternFilter
                touch: true
                text: Session.histogramFilterLabel
                onRemoveRequested: Session.clearHistogramFilter()
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: qsTr("Tap a bar to see the entries of that interval; tap a level to show only it.")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
    }
}
