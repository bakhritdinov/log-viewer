import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Temporary focus around one entry: its context (all entries of the app in a
// window) or its trace. Explicit and reversible: Esc returns to the search.
ColumnLayout {
    id: root

    readonly property var session: Session.focus
    property int selectedRow: -1
    property alias table: table

    spacing: 0
    onVisibleChanged: selectedRow = -1

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: bar.implicitHeight + 20
        color: Theme.tint(Theme.accent, 0.08)
        Accessible.role: Accessible.Grouping
        Accessible.name: qsTr("Focus mode")
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.accentBorder }

        RowLayout {
            id: bar
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14
            AppButton {
                id: backButton
                text: qsTr("Back to search results")
                Accessible.name: text
                onClicked: root.session.close()
                contentItem: Row {
                    spacing: 6
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronLeft"; size: 14; color: backButton._fg }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: backButton.text
                        font: backButton.font
                        color: backButton._fg
                    }
                    Kbd { anchors.verticalCenter: parent.verticalCenter; text: "Esc" }
                }
            }
            SegmentedControl {
                accent: true
                accessibleName: qsTr("What to show around the entry")
                model: root.session.canShowTrace
                       ? [{ label: qsTr("Context"), value: 1 }, { label: qsTr("Trace %1…").arg(root.session.traceId.slice(0, 6)), value: 2 }]
                       : [{ label: qsTr("Context"), value: 1 }]
                value: root.session.mode
                onActivated: v => v === 2 ? root.session.showTrace() : root.session.showContext()
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.session.mode === 2
                      ? qsTr("Entries of trace %1 around %2").arg(root.session.traceId).arg(root.session.anchorTimeText)
                      : qsTr("All %1 entries around %2 · search filters are lifted for now").arg(Session.app).arg(root.session.anchorTimeText)
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.text
            }
            SegmentedControl {
                visible: root.session.mode === 1
                accessibleName: qsTr("Window")
                model: [{ label: qsTr("±30 s"), value: 30 }, { label: qsTr("±1 min"), value: 60 }, { label: qsTr("±5 min"), value: 300 }]
                value: root.session.windowSeconds
                onActivated: v => root.session.windowSeconds = v
            }
        }
    }

    ErrorBanner {
        Layout.fillWidth: true
        error: root.session.error
        visible: active
        onActionTriggered: root.session.showContext()
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        LogTable {
            id: table
            anchors.fill: parent
            model: root.session.logs
            anchorRow: root.session.anchorRow
            currentRow: root.selectedRow
            onRowClicked: row => root.selectedRow = row
            onMoveRequested: delta => root.selectedRow = Math.max(0, Math.min(root.session.logs.totalCount - 1, root.selectedRow + delta))
        }

        // Still loading: grey rows under the header.
        Column {
            anchors.fill: parent
            anchors.topMargin: 36
            visible: root.session.loading && root.session.logs.totalCount === 0
            spacing: 18
            leftPadding: 16
            Repeater {
                model: [0.7, 0.55, 0.8, 0.6, 0.75, 0.5]
                delegate: Rectangle {
                    required property real modelData
                    width: (parent.width - 32) * modelData
                    height: 10
                    radius: Theme.radiusSm
                    color: Theme.subtle
                }
            }
        }
        // Loaded, but nothing around the entry.
        EmptyState {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 460)
            // A trace of the entry alone counts as empty; the entry stays visible above.
            anchors.verticalCenterOffset: root.session.logs.totalCount > 0 ? 40 : 0
            visible: !root.session.loading && !root.session.error.active
                     && root.session.logs.totalCount <= (root.session.mode === 2 ? 1 : 0)
            iconName: root.session.mode === 2 ? "trace" : "clock"
            title: root.session.mode === 2
                   ? qsTr("No other entries with trace_id %1 within ±5 min").arg(root.session.traceId.slice(0, 8) + "…")
                   : qsTr("No entries around %1").arg(root.session.anchorTimeText)
            message: root.session.mode === 2 ? qsTr("Other services may write the trace id into another field.")
                                             : qsTr("Try a wider window.")
            AppButton {
                visible: root.session.mode === 2
                text: qsTr("Show the context")
                onClicked: root.session.showContext()
            }
            AppButton {
                visible: root.session.mode !== 2 && root.session.windowSeconds < 300
                text: qsTr("Widen to ±5 min")
                onClicked: root.session.windowSeconds = 300
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 44
        color: Theme.bg
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.borderMuted }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            Text {
                Layout.fillWidth: true
                text: root.session.loading ? qsTr("Loading…")
                      : qsTr("Showing %n entries · %1 · the selected entry is highlighted", "", root.session.logs.totalCount).arg(root.session.windowText)
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textMuted
            }
            AppButton { text: qsTr("Open as search"); onClicked: root.session.openAsSearch() }
        }
    }
}
