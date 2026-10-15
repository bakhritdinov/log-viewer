import QtQuick
import QtQuick.Controls.Basic

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

    signal bucketClicked(int index, string level)

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
                readonly property var segments: [
                    { level: "ERROR", count: error },
                    { level: "WARN", count: warn },
                    { level: "INFO", count: info },
                    { level: "", count: debug + trace + other },
                ]

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
                    Repeater {
                        // Top-down: other, INFO, WARN, ERROR so ERROR sits at the bottom.
                        model: bar.segments.slice().reverse()
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: modelData.count * bar.unit
                            color: modelData.level === "" ? Theme.levelColor("DEBUG") : Theme.levelColor(modelData.level)
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

                HoverHandler { id: hover; enabled: root.interactive }
                TapHandler {
                    enabled: root.interactive
                    onTapped: (point) => {
                        // Which segment was hit, counting up from the bottom.
                        let y = bar.height - point.position.y
                        for (const s of bar.segments) {
                            y -= s.count * bar.unit
                            if (y <= 0) { root.bucketClicked(bar.index, s.level); return }
                        }
                        root.bucketClicked(bar.index, "")
                    }
                }
                ToolTip.visible: root.showTooltip && hover.hovered
                ToolTip.delay: 150
                ToolTip.text: qsTr("%1 · %n entries", "", bar.total).arg(bar.timeText)
                              + (bar.error > 0 ? "\n" + qsTr("ERROR %1").arg(bar.error) : "")
                              + (bar.warn > 0 ? "\n" + qsTr("WARN %1").arg(bar.warn) : "")
            }
        }
    }
}
