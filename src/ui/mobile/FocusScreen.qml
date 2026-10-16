pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// A temporary view around one entry, over everything (no bottom navigation):
// its context (all entries of the app in a window, search filters lifted) or
// its trace (entries of several services, the service on each card). The
// entry itself has a blue frame and is scrolled to the middle. Back returns
// to the entry.
Popup {
    id: root

    signal entryRequested(int row)
    signal searchOpened()

    readonly property var session: Session.focus
    readonly property bool trace: session.mode === FocusSession.Trace
    // Services among the trace's entries (a trace spans several).
    readonly property int serviceCount: {
        void session.logs.totalCount
        const names = new Set()
        for (let i = 0; i < session.logs.rowCount(); ++i) names.add(session.logs.rowData(i).service)
        return names.size
    }

    function leave() {
        session.close()
        close()
    }

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.NoAutoClose
    background: Rectangle { color: Theme.bg }
    enter: Transition { NumberAnimation { property: "x"; from: root.width; to: 0; duration: 160; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "x"; from: 0; to: root.width; duration: 140; easing.type: Easing.InCubic } }

    // The entry in the middle once its neighbours are loaded.
    Connections {
        target: root.session
        function onLoadingChanged() {
            if (!root.session.loading && root.session.anchorRow >= 0)
                Qt.callLater(() => list.positionViewAtIndex(root.session.anchorRow, ListView.Center))
        }
    }

    contentItem: ColumnLayout {
        spacing: 0
        focus: true
        Keys.onBackPressed: root.leave()
        Keys.onEscapePressed: root.leave()
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Around the entry")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: barColumn.implicitHeight + 12
            color: Theme.surface
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
            ColumnLayout {
                id: barColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.leftMargin: 4
                anchors.rightMargin: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    AbstractButton {
                        id: back
                        implicitHeight: 44
                        implicitWidth: backRow.implicitWidth + 14
                        Accessible.name: qsTr("Entry")
                        onClicked: root.leave()
                        background: Rectangle { radius: Theme.radiusMd; color: back.pressed ? Theme.subtle : "transparent" }
                        contentItem: Item {
                            Row {
                                id: backRow
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronLeft"; size: 20; color: Theme.accentText }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Entry")
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontXl - 1
                                    font.weight: Font.Medium
                                    color: Theme.accentText
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.trace ? qsTr("Trace %1…").arg(root.session.traceId.slice(0, 6))
                                         : qsTr("Around %1").arg(root.session.anchorTimeText)
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXl - 1
                        font.weight: Font.DemiBold
                        color: Theme.textStrong
                    }
                }
                SegmentedControl {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    touch: true
                    fill: true
                    accent: true
                    accessibleName: qsTr("What to show around the entry")
                    model: root.session.canShowTrace
                           ? [{ label: qsTr("Context"), value: FocusSession.Context }, { label: qsTr("Trace %1…").arg(root.session.traceId.slice(0, 6)), value: FocusSession.Trace }]
                           : [{ label: qsTr("Context"), value: FocusSession.Context }]
                    value: root.session.mode
                    onActivated: v => v === FocusSession.Trace ? root.session.showTrace() : root.session.showContext()
                }
                SegmentedControl {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    visible: !root.trace
                    touch: true
                    fill: true
                    accessibleName: qsTr("Window")
                    model: [{ label: qsTr("±30 s"), value: 30 }, { label: qsTr("±1 min"), value: 60 }, { label: qsTr("±5 min"), value: 300 }]
                    value: root.session.windowSeconds
                    onActivated: v => root.session.windowSeconds = v
                }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    text: root.trace
                          ? qsTr("%n entries", "", root.session.logs.totalCount) + " · " + qsTr("%n service(s)", "", root.serviceCount) + " · " + root.session.windowText
                          : qsTr("All %1 entries · search filters are lifted").arg(Session.app)
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
        }

        ErrorBanner {
            Layout.fillWidth: true
            Layout.margins: 12
            touch: true
            error: root.session.error
            visible: active
            onActionTriggered: root.session.showContext()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                topMargin: 12
                bottomMargin: 12
                leftMargin: 12
                rightMargin: 12
                spacing: 8
                clip: true
                model: root.session.logs
                Accessible.role: Accessible.List
                Accessible.name: qsTr("Entries around")
                delegate: LogCard {
                    required property var model
                    width: ListView.view.width - 24
                    anchor: index === root.session.anchorRow
                    service: root.trace ? model.service : ""
                    lines: Math.max(2, Session.prefs.messageLines)
                    onClicked: root.entryRequested(index)
                }
            }

            // Still loading: grey cards.
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                topPadding: 12
                spacing: 8
                visible: root.session.loading && root.session.logs.totalCount === 0
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        width: parent.width
                        height: 72
                        radius: Theme.radiusLg
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.borderMuted
                    }
                }
            }

            // Nothing around the entry (a trace of the entry alone counts as empty).
            EmptyState {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.session.logs.totalCount > 0 ? 60 : 0
                visible: !root.session.loading && !root.session.error.active
                         && root.session.logs.totalCount <= (root.trace ? 1 : 0)
                touch: true
                iconName: root.trace ? "trace" : "clock"
                title: root.trace ? qsTr("No other entries of the trace within ±5 min")
                                  : qsTr("No entries around %1").arg(root.session.anchorTimeText)
                message: root.trace ? qsTr("Other services may write the trace id into another field.")
                                    : qsTr("Try a wider window.")
                AppButton {
                    width: parent ? parent.width : 0
                    visible: root.trace
                    touch: true
                    text: qsTr("Show the context")
                    onClicked: root.session.showContext()
                }
                AppButton {
                    width: parent ? parent.width : 0
                    visible: !root.trace && root.session.windowSeconds < 300
                    touch: true
                    text: qsTr("Widen to ±5 min")
                    onClicked: root.session.windowSeconds = 300
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            color: Theme.surface
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: root.session.loading ? qsTr("Loading…")
                          : qsTr("%n entries", "", root.session.logs.totalCount) + " · " + root.session.windowText
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    color: Theme.text
                }
                AppButton {
                    touch: true
                    text: qsTr("Open as search")
                    onClicked: { root.session.openAsSearch(); root.close(); root.searchOpened() }
                }
            }
        }
    }
}
