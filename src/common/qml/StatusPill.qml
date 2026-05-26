import QtQuick
import QtQuick.Controls
import LogViewerApp

// Reusable status chip used across the Ecotone UI:
//   * Aggregate counters in EcotoneWindow (filter strip) and
//     ReplayByContractDialog summary row — pass `count`.
//   * Single-row badges (EcotoneDetailsPane, per-row preview rows) —
//     pass `requestId`, leave `count = -1`.
//
// The colour palette is keyed on the ecotone_replay_requests status string
// (pending | processing | done | failed) plus the special "not_queued"
// fallback for rows that have never been replayed.
Rectangle {
    id: root

    property string status: ""               // status from ecotone_replay_requests
    property string label: status            // visible text (caller may humanise)
    property int    count: -1                // -1 = don't render a count
    property string requestId: ""            // optional "#42" suffix
    property bool   dimWhenZero: count >= 0  // dim if showing a count that's 0

    readonly property color fg: status === "pending"     ? Theme.warn
                              : status === "processing"  ? Theme.accent
                              : status === "done"        ? Theme.success
                              : status === "failed"      ? Theme.danger
                              : Theme.textMuted
    readonly property color bg: status === "pending"     ? Qt.rgba(0.82, 0.60, 0.13, 0.20)
                              : status === "processing"  ? Qt.rgba(0.34, 0.65, 1.00, 0.22)
                              : status === "done"        ? Qt.rgba(0.25, 0.73, 0.31, 0.22)
                              : status === "failed"      ? Qt.rgba(0.97, 0.32, 0.29, 0.22)
                              : Theme.bgSubtle

    implicitHeight: 22
    implicitWidth: pillContent.implicitWidth + Theme.sp3
    radius: Theme.rSm
    color: root.bg
    border.color: root.fg
    border.width: 1
    opacity: (root.dimWhenZero && root.count === 0) ? 0.35 : 1.0
    Behavior on opacity { NumberAnimation { duration: Theme.dFast } }

    Row {
        id: pillContent
        anchors.centerIn: parent
        spacing: 4
        Label {
            text: root.label
            color: root.fg
            font.pixelSize: Theme.fsSm
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            visible: root.count >= 0
            text: root.count
            color: root.fg
            font.pixelSize: Theme.fsSm
            font.family: "Monospace"
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            visible: root.requestId !== ""
            text: "#" + root.requestId
            color: root.fg
            font.pixelSize: Theme.fsSm
            font.family: "Monospace"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
