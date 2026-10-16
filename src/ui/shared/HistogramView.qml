pragma ComponentBehavior: Bound
import QtQuick

// Stacked bars of log volume per time bucket (ERROR, WARN, INFO, other from the
// bottom). Clicking a level segment filters by bucket and level; clicking the
// rest of a bar filters by bucket only.
Item {
    id: root

    property var model                  // startMs, timeText, error, warn, info, debug, trace, other, total
    property int maxTotal: 1
    property int selectedIndex: -1
    property bool interactive: true
    property bool showTooltip: true
    // Only this level's segments ("ERROR"/"WARN"; "" both): a level filter hides the other.
    property string onlyLevel

    signal bucketClicked(int index, string level)
    signal resetRequested()                 // double click: back to all entries

    implicitHeight: 80
    Accessible.role: Accessible.Chart
    Accessible.name: qsTr("Log volume over time")

    Row {
        id: bars
        anchors.fill: parent
        spacing: Math.max(1, Math.min(3, width / Math.max(1, repeater.count) / 6))

        Repeater {
            id: repeater
            model: root.model
            delegate: Item {
                id: bar
                required property int index
                required property string timeText
                required property int error
                required property int warn
                required property int info
                required property int debug
                required property int trace
                required property int other
                required property int total

                readonly property real unit: bars.height / Math.max(1, root.maxTotal)
                // WARN and above, as in 2.8: WARN at the bottom, ERROR on top.
                readonly property var segments: [
                    { level: "WARN", count: warn },
                    { level: "ERROR", count: error },
                ].filter(s => root.onlyLevel === "" || s.level === root.onlyLevel)

                width: (bars.width - bars.spacing * (repeater.count - 1)) / Math.max(1, repeater.count)
                height: bars.height

                Rectangle {
                    anchors.fill: parent
                    color: hover.hovered || bar.index === root.selectedIndex ? Theme.subtle : "transparent"
                    radius: 2
                }
                Column {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    // A picked interval keeps its colour; the rest steps back.
                    opacity: root.selectedIndex >= 0 && bar.index !== root.selectedIndex ? 0.35 : 1
                    Repeater {
                        // A Column lays out top-down: reversed so WARN sits at the bottom.
                        model: bar.segments.slice().reverse()
                        delegate: Rectangle {
                            required property var modelData
                            width: bar.width
                            height: modelData.count * bar.unit
                            color: Theme.levelColor(modelData.level)
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: bar.index === root.selectedIndex
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.textStrong
                    radius: 2
                }

                // Empty buckets (no WARN/ERROR) are not targets: no hover, tooltip or click.
                readonly property bool hasEntries: error + warn > 0
                HoverHandler { id: hover; enabled: root.interactive && bar.hasEntries }
                // Which level a click at `y` (bar coordinates) hits, counting up from the bottom.
                function levelAt(y) {
                    let rest = bar.height - y
                    for (const s of bar.segments) {
                        rest -= s.count * bar.unit
                        if (rest <= 0) return s.level
                    }
                    return ""
                }
                AppToolTip {
                    visible: root.showTooltip && hover.hovered
                    delay: 150
                    y: -height - 6
                    text: qsTr("%1 · %n entries", "", bar.error + bar.warn).arg(bar.timeText)
                          + (bar.error > 0 ? "\n" + qsTr("ERROR %1").arg(bar.error) : "")
                          + (bar.warn > 0 ? "\n" + qsTr("WARN %1").arg(bar.warn) : "")
                          + (root.interactive ? "\n" + qsTr("Click to show only this interval") : "")
                }
            }
        }
    }

    // One handler for the whole chart: a click picks a bucket (and level), a
    // double click anywhere clears the filter. Empty buckets are not targets.
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        onClicked: mouse => {
            // childAt() is typed as a plain Item; it is one of the bar delegates.
            const bar = bars.childAt(mouse.x, 1)
            if (bar && bar.hasEntries) root.bucketClicked(bar.index, bar.levelAt(mouse.y)) // qmllint disable missing-property
        }
        onDoubleClicked: root.resetRequested()
    }
}
