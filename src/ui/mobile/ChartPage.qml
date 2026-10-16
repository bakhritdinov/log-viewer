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
    signal settingsRequested()

    readonly property var steps: [
        { label: qsTr("Auto"), value: 0 },
        { label: qsTr("1 min"), value: 60000 },
        { label: qsTr("5 min"), value: 300000 },
        { label: qsTr("1 h"), value: 3600000 },
    ]

    // Nothing to draw (no connection, a failed request, an empty period): no
    // step switch or hints over an empty chart, just why.
    readonly property bool hasData: Session.histogram.count > 0 && Session.histogramMax > 0

    // The bucket under the finger while sliding over the chart (-1: none).
    property int scrubIndex: -1
    // The picked interval (its bucket), when the feed is narrowed to one.
    readonly property int selectedIndex: {
        void Session.histogramMax
        const from = Session.histogramFilterFromMs
        if (from <= 0) return -1
        for (let i = 0; i < Session.histogram.count; ++i)
            if (Session.histogram.get(i).startMs === from) return i
        return -1
    }
    readonly property int cardIndex: scrubIndex >= 0 ? scrubIndex : selectedIndex
    readonly property var cardBucket: cardIndex >= 0 ? Session.histogram.get(cardIndex) : null
    function intervalText(bucket) {
        const from = new Date(bucket.startMs)
        const to = new Date(bucket.startMs + Session.histogramBucketMs)
        const format = Session.histogramBucketMs < 60000 ? "HH:mm:ss" : "HH:mm"
        return Qt.formatTime(from, format) + " – " + Qt.formatTime(to, format)
    }

    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 60                     // as the Logs bar: the guide below sits at the same place
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

    // Nothing connected: the same guide as in Logs, at the same place.
    SetupGuide {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Session.needsSetup
        onSettingsRequested: root.settingsRequested()
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.hasData && !Session.needsSetup
        // Still loading: grey bars.
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            anchors.topMargin: 76
            height: 200
            spacing: 3
            visible: Session.loading
            Repeater {
                model: 24
                delegate: Rectangle {
                    required property int index
                    anchors.bottom: parent ? parent.bottom : undefined
                    width: (parent ? parent.width - 23 * 3 : 0) / 24
                    height: 200 * (0.25 + 0.5 * Math.abs(Math.sin(index / 3)))
                    radius: 2
                    color: Theme.subtle
                }
            }
        }
        EmptyState {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            touch: true
            visible: !Session.loading
            iconName: "chart"
            title: Session.hasError ? qsTr("No chart — the request failed")
                 : qsTr("Nothing to chart")
            message: Session.hasError ? qsTr("The reason is shown in the Logs section.")
                   : qsTr("No entries for “%1”.").arg(Session.timeRangeLabel)
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.hasData && !Session.needsSetup
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
                // A filter, as on the desktop: the chart shows that level only.
                onToggled: level => Session.applyLevelFilter(level)
            }
            // Slide a finger over the chart: the card below follows the interval
            // under it; lifting the finger picks that interval.
            HistogramView {
                id: chart
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                model: Session.histogram
                maxTotal: Session.histogramMax
                showTooltip: false
                interactive: false
                selectedIndex: root.cardIndex
                onlyLevel: Session.activeLevel
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function indexAt(x) {
                        const n = Session.histogram.count
                        return Math.max(0, Math.min(n - 1, Math.floor(x / width * n)))
                    }
                    onPressed: mouse => root.scrubIndex = indexAt(mouse.x)
                    onPositionChanged: mouse => { if (pressed) root.scrubIndex = indexAt(mouse.x) }
                    onReleased: {
                        const index = root.scrubIndex
                        root.scrubIndex = -1
                        // The chart draws WARN and ERROR: a pick shows those (or the
                        // level chosen above), not the INFO around them.
                        if (index >= 0) Session.applyBucketFilter(index, Session.activeLevel, Session.activeLevel === "")
                    }
                    onCanceled: root.scrubIndex = -1
                }
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
            // The interval under the finger, or the one picked.
            Rectangle {
                id: intervalCard
                readonly property var bucket: root.cardBucket
                readonly property bool picked: root.scrubIndex < 0
                // What a pick shows: the chosen level, or WARN and ERROR together.
                readonly property int shownHere: bucket === null ? 0
                                                 : Session.activeLevel === "ERROR" ? bucket.error
                                                 : Session.activeLevel === "WARN" ? bucket.warn
                                                 : bucket.important
                // Nothing of that here (a finger can pick a quiet interval too).
                readonly property bool emptyForLevel: bucket !== null && shownHere === 0
                readonly property bool offerErrors: !emptyForLevel && bucket !== null && bucket.error > 0 && bucket.warn > 0
                                                    && Session.activeLevel !== "ERROR"
                // The rest of the interval (INFO, DEBUG…) on request.
                readonly property bool offerAllLevels: bucket !== null && bucket.total > Session.logs.totalCount
                Layout.fillWidth: true
                visible: bucket !== null
                implicitHeight: cardColumn.implicitHeight + 24
                radius: Theme.radiusLg
                color: Theme.surface
                border.width: 1
                border.color: picked ? Theme.accentBorder : Theme.border
                ColumnLayout {
                    id: cardColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: intervalCard.bucket ? root.intervalText(intervalCard.bucket) : ""
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.DemiBold
                            color: Theme.textStrong
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: intervalCard.picked
                            text: qsTr("picked interval")
                            elide: Text.ElideRight
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                            color: Theme.textMuted
                        }
                    }
                    Row {
                        visible: !intervalCard.emptyForLevel
                        spacing: 16
                        Repeater {
                            model: ["ERROR", "WARN"]
                            delegate: Row {
                                id: count
                                required property string modelData
                                spacing: 6
                                Text {
                                    text: count.modelData
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontSm
                                    font.weight: Font.DemiBold
                                    color: Theme.levelTextColor(count.modelData)
                                }
                                Text {
                                    text: !intervalCard.bucket ? "" : count.modelData === "ERROR" ? intervalCard.bucket.error : intervalCard.bucket.warn
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontMd
                                    color: Theme.text
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: intervalCard.emptyForLevel
                        text: Session.activeLevel !== "" ? qsTr("No %1 in this interval").arg(Session.activeLevel)
                                                         : qsTr("No ERROR or WARN in this interval")
                        wrapMode: Text.Wrap
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontLg
                        color: Theme.textStrong
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: intervalCard.picked
                        spacing: 8
                        AppButton {
                            Layout.fillWidth: true
                            touch: true
                            variant: intervalCard.emptyForLevel ? "secondary" : "primary"
                            text: intervalCard.emptyForLevel ? qsTr("Show the whole period")
                                                             : qsTr("Show %n entries", "", Session.logs.totalCount)
                            onClicked: {
                                if (intervalCard.emptyForLevel) Session.clearHistogramFilter()
                                else root.showEntriesRequested()
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: intervalCard.offerErrors || intervalCard.offerAllLevels
                            spacing: 8
                            AppButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                visible: intervalCard.offerErrors
                                touch: true
                                text: qsTr("Only ERROR")
                                onClicked: { Session.applyBucketFilter(root.cardIndex, "ERROR"); root.showEntriesRequested() }
                            }
                            AppButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                visible: intervalCard.offerAllLevels
                                touch: true
                                text: qsTr("All levels · %1").arg(intervalCard.bucket ? intervalCard.bucket.total : 0)
                                onClicked: { Session.applyBucketFilter(root.cardIndex, ""); root.showEntriesRequested() }
                            }
                        }
                    }
                }
            }
            FilterChip {
                visible: Session.histogramRangeOrPatternFilter && root.selectedIndex < 0
                touch: true
                text: Session.histogramFilterLabel
                onRemoveRequested: Session.clearHistogramFilter()
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: qsTr("Slide a finger over the chart to pick an interval; tap a level to show only it.")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
    }
}
