import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

// Universal replay dialog for FIFO channel groups.
//
// One TabBar tab per FifoGroup (Contract, Client, …). Each tab owns its own
// state — search value, preview rows, in-progress flag, polling. Tabs do
// not share state so switching is non-destructive.
//
// Backend contract:
//   ecotoneClient.previewFifoGroup(groupId, value) → fifoGroupPreviewReceived
//   ecotoneClient.replayFifoGroup(groupId, value)  → replayQueued / replayFailed
Dialog {
    id: root
    title: qsTr("Replay FIFO group")
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 760
    height: 640

    property string envName: ""

    // groupsModel is the QVariantList from FifoChannels::groups().
    property var groupsModel: typeof fifoChannels !== "undefined"
                              ? fifoChannels.groups() : []

    // True between the moment the user clicks Replay and the C++ side
    // emits replayQueued / replayFailed. Used to disable the button so
    // a double-click doesn't fire a second transaction.
    property bool replaying: false

    // Bubble up the user's intent so EcotoneWindow can wire it to the
    // C++ client. We pass (groupId, searchValue) so the window doesn't need
    // to know which tab is active.
    signal confirmed(string groupId, string searchValue)

    background: Rectangle {
        color: Theme.bgRaised
        border.color: Theme.warn
        border.width: 1
        radius: Theme.rLg
    }

    header: Rectangle {
        color: "transparent"
        implicitHeight: 50
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp2
            Text { text: "↻"; color: Theme.warn; font.pixelSize: Theme.fsXl; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.title; color: Theme.text; font.pixelSize: Theme.fsLg; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    }

    Connections {
        target: typeof ecotoneClient !== "undefined" ? ecotoneClient : null
        ignoreUnknownSignals: true
        function onFifoGroupPreviewReceived(groupId, searchValue, entries) {
            if (!root.visible) return
            const page = root._pageFor(groupId)
            if (!page) return
            if (searchValue !== page.lastQueriedValue) return
            page.previewRows    = entries
            page.previewLoaded  = true
            page.previewLoading = false
        }
        function onReplayQueued(firstRequestId, count) {
            root.replaying = false
            if (!root.visible) return
            const page = root._pageFor(root.currentGroupId())
            if (!page) return
            page.inProgress    = true
            page.queuedFirstId = firstRequestId
            page.queuedCount   = count
            page.startPolling()
        }
        function onReplayFailed(reason) {
            // We don't show the reason here — EcotoneWindow's footer status
            // already surfaces it. We only release the button.
            root.replaying = false
        }
    }

    function currentGroupId() {
        if (!root.groupsModel || tabs.currentIndex < 0) return ""
        if (tabs.currentIndex >= root.groupsModel.length) return ""
        return root.groupsModel[tabs.currentIndex].id
    }

    function _pageFor(groupId) {
        for (let i = 0; i < pagesRepeater.count; ++i) {
            const item = pagesRepeater.itemAt(i)
            if (item && item.groupId === groupId) return item
        }
        return null
    }

    // Single pop-out window reused across row clicks. Doesn't block the
    // dialog (non-modal Window), so operator can keep both visible.
    MessageDetailsWindow { id: detailsWindow }

    function openDetailsFor(row) {
        if (!row) return
        detailsWindow.messageId       = row.messageId       || ""
        detailsWindow.failedAt        = row.failedAt
                                        ? Qt.formatDateTime(row.failedAt, "yyyy-MM-dd hh:mm:ss")
                                        : ""
        detailsWindow.channel         = row.channel         || ""
        detailsWindow.contractId      = row.contractId      || ""
        detailsWindow.payload         = row.payload         || ""
        detailsWindow.headers         = row.headers         || ""
        detailsWindow.replayStatus    = row.replayStatus    || ""
        detailsWindow.replayRequestId = row.replayRequestId || 0
        detailsWindow.show()
        detailsWindow.raise()
        detailsWindow.requestActivate()
    }

    contentItem: ColumnLayout {
        spacing: Theme.sp2

        TabBar {
            id: tabs
            Layout.fillWidth: true
            background: Rectangle { color: "transparent" }
            Repeater {
                model: root.groupsModel
                TabButton {
                    text: modelData.label
                    implicitHeight: Theme.hButton + 4
                }
            }
        }

        StackLayout {
            id: pageStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            Repeater {
                id: pagesRepeater
                model: root.groupsModel
                GroupPage {
                    groupId:           modelData.id
                    groupLabel:        modelData.label
                    searchField:       modelData.searchField
                    searchPlaceholder: modelData.searchPlaceholder
                }
            }
        }
    }

    footer: Rectangle {
        color: "transparent"
        implicitHeight: 60
        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp4
            anchors.rightMargin: Theme.sp4
            spacing: Theme.sp2

            Label {
                text: root.envName ? qsTr("Env: %1").arg(root.envName) : ""
                color: Theme.textMuted
                font.pixelSize: Theme.fsSm
            }
            Item { Layout.fillWidth: true }

            SecondaryButton {
                property var _activePage: root._pageFor(root.currentGroupId())
                text: _activePage && _activePage.inProgress ? qsTr("Close") : qsTr("Cancel")
                Layout.preferredWidth: 110
                onClicked: root.reject()
            }
            PrimaryButton {
                property var _activePage: root._pageFor(root.currentGroupId())
                // "Actionable" rows are ones the worker hasn't already accepted —
                // pending and processing requests stay live in the DB so a
                // second click would be a no-op (the C++ INSERT also filters
                // them out). failed rows can be retried.
                property int _actionable: _activePage
                    ? (_activePage.notQueuedCount + _activePage.failedCount) : 0
                visible: !_activePage || !_activePage.inProgress
                text: root.replaying ? qsTr("Queueing…") : qsTr("Replay")
                Layout.preferredWidth: 130
                enabled: !root.replaying
                         && _activePage && _activePage.previewLoaded
                         && _activePage.previewRows.length > 0
                         && _actionable > 0
                ToolTip.text: root.replaying
                              ? qsTr("Writing %1 row(s) to ecotone_replay_requests…").arg(_actionable)
                              : (_actionable > 0
                                 ? qsTr("Queue %1 message(s) for replay").arg(_actionable)
                                 : qsTr("Nothing to queue — all messages are already pending/processing/done"))
                ToolTip.visible: _activePage && _activePage.previewRows.length > 0 && hovered
                ToolTip.delay: 400
                onClicked: {
                    if (!_activePage) return
                    root.replaying = true
                    root.confirmed(_activePage.groupId, _activePage.lastQueriedValue)
                }
            }
        }
    }

    onClosed: {
        for (let i = 0; i < pagesRepeater.count; ++i) {
            const p = pagesRepeater.itemAt(i)
            if (p) p.stopPolling()
        }
        if (detailsWindow.visible) detailsWindow.close()
    }

    onAboutToShow: {
        for (let i = 0; i < pagesRepeater.count; ++i) {
            const p = pagesRepeater.itemAt(i)
            if (p) p.resetState()
        }
        tabs.currentIndex = 0
        root.replaying = false
    }

    // One tab body — owns its own search, preview and progress state.
    component GroupPage : Item {
        id: page
        property string groupId: ""
        property string groupLabel: ""
        property string searchField: ""
        property string searchPlaceholder: ""

        property string lastQueriedValue: ""
        property var    previewRows: []
        property bool   previewLoaded: false
        property bool   previewLoading: false

        property bool inProgress: false
        property int  queuedFirstId: 0
        property int  queuedCount: 0

        // Derived from previewRows after each refresh — exposed so the
        // dialog footer can decide whether Replay is actionable.
        property int notQueuedCount:  0
        property int pendingCount:    0
        property int processingCount: 0
        property int doneCount:       0
        property int failedCount:     0

        function resetState() {
            inputField.text = ""
            previewRows = []
            previewLoaded = false
            previewLoading = false
            lastQueriedValue = ""
            inProgress = false
            queuedFirstId = 0
            queuedCount = 0
            statusPoll.stop()
        }
        function startPolling() { statusPoll.start() }
        function stopPolling()  { statusPoll.stop() }

        Timer {
            id: statusPoll
            interval: 3000
            repeat: true
            running: false
            onTriggered: {
                if (page.lastQueriedValue === "") { stop(); return }
                ecotoneClient.previewFifoGroup(page.groupId, page.lastQueriedValue)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.sp3

            Label {
                visible: !page.inProgress
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fsMd
                color: Theme.text
                text: qsTr("Search by %1. Messages are queued in failed_at ASC order across this group's channels (errors-first happens naturally because they failed earliest).").arg(page.searchField)
            }
            RowLayout {
                visible: !page.inProgress
                Layout.fillWidth: true
                spacing: Theme.sp2
                AppTextField {
                    id: inputField
                    Layout.fillWidth: true
                    implicitHeight: Theme.hInput
                    placeholderText: page.searchPlaceholder
                    onAccepted: previewBtn.clicked()
                }
                PrimaryButton {
                    id: previewBtn
                    text: qsTr("Preview")
                    enabled: inputField.text.trim() !== "" && !page.previewLoading
                    onClicked: {
                        if (typeof ecotoneClient === "undefined" || ecotoneClient === null) return
                        page.lastQueriedValue = inputField.text.trim()
                        page.previewLoading = true
                        page.previewLoaded = false
                        ecotoneClient.previewFifoGroup(page.groupId, page.lastQueriedValue)
                    }
                }
            }

            Rectangle {
                id: summaryBox
                visible: page.previewLoaded && page.previewRows.length > 0
                Layout.fillWidth: true
                color: Theme.bgInput
                border.color: Theme.borderMuted
                border.width: 1
                radius: Theme.rSm
                implicitHeight: summaryCol.implicitHeight + Theme.sp3 * 2

                property int nPending:    0
                property int nProcessing: 0
                property int nDone:       0
                property int nFailed:     0
                property int nNotQueued:  0
                function recomputeCounts() {
                    let p = 0, pr = 0, d = 0, f = 0, nq = 0
                    const rows = page.previewRows
                    for (let i = 0; i < rows.length; ++i) {
                        const s = rows[i].replayStatus || ""
                        if      (s === "pending")    p++
                        else if (s === "processing") pr++
                        else if (s === "done")       d++
                        else if (s === "failed")     f++
                        else                         nq++
                    }
                    nPending = p; nProcessing = pr; nDone = d; nFailed = f; nNotQueued = nq
                    // Mirror onto page so the dialog footer can react.
                    page.notQueuedCount  = nq
                    page.pendingCount    = p
                    page.processingCount = pr
                    page.doneCount       = d
                    page.failedCount     = f
                }
                Connections {
                    target: page
                    function onPreviewRowsChanged() { summaryBox.recomputeCounts() }
                }

                ColumnLayout {
                    id: summaryCol
                    anchors.fill: parent
                    anchors.margins: Theme.sp3
                    spacing: 6

                    Label {
                        text: page.inProgress
                              ? qsTr("Replay queued for %1=%2 — %3 message(s), starting at request #%4")
                                    .arg(page.searchField).arg(page.lastQueriedValue)
                                    .arg(page.queuedCount).arg(page.queuedFirstId)
                              : qsTr("%1=%2 — %3 message(s) in the DLQ")
                                    .arg(page.searchField).arg(page.lastQueriedValue).arg(page.previewRows.length)
                        color: Theme.text
                        font.pixelSize: Theme.fsMd
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp3

                        StatusPill { status: "not_queued"; label: qsTr("not queued"); count: summaryBox.nNotQueued }
                        StatusPill { status: "pending";    count: summaryBox.nPending }
                        StatusPill { status: "processing"; count: summaryBox.nProcessing }
                        StatusPill { status: "done";       count: summaryBox.nDone }
                        StatusPill { status: "failed";     count: summaryBox.nFailed }

                        Item { Layout.fillWidth: true }
                        Label {
                            visible: page.inProgress
                            text: qsTr("polling every 3s")
                            color: Theme.textDim
                            font.pixelSize: Theme.fsXs
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.bgInput
                border.color: Theme.borderMuted
                border.width: 1
                radius: Theme.rSm

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.sp3
                    spacing: Theme.sp2

                    Label {
                        visible: !page.previewLoaded && !page.previewLoading
                        text: qsTr("No preview yet — enter a value and click Preview.")
                        color: Theme.textDim
                        font.pixelSize: Theme.fsSm
                    }
                    Label {
                        visible: page.previewLoading
                        text: qsTr("Querying ecotone_error_messages for %1=%2…")
                                .arg(page.searchField).arg(page.lastQueriedValue)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsSm
                    }
                    Label {
                        visible: page.previewLoaded && page.previewRows.length === 0 && !page.inProgress
                        text: qsTr("No error messages found for %1=%2.")
                                .arg(page.searchField).arg(page.lastQueriedValue)
                        color: Theme.warn
                        font.pixelSize: Theme.fsSm
                    }
                    ListView {
                        visible: page.previewLoaded && page.previewRows.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: page.previewRows
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        // Item delegate so we can layer a MouseArea+hover Rectangle
                        // underneath the row content. Whole row reacts to clicks.
                        delegate: Item {
                            id: rowItem
                            width: ListView.view.width
                            height: rowLayout.implicitHeight + 4

                            Rectangle {
                                anchors.fill: parent
                                color: rowMouse.containsMouse ? Theme.rowHover : "transparent"
                                radius: Theme.rSm
                                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                            }

                            RowLayout {
                                id: rowLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 2
                                anchors.rightMargin: 2
                                spacing: Theme.sp2

                                Label {
                                    text: (index + 1) + "."
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fsXs
                                    font.family: "Monospace"
                                    Layout.preferredWidth: 36
                                }
                                Label {
                                    text: modelData.failedAt
                                          ? Qt.formatDateTime(modelData.failedAt, "yyyy-MM-dd hh:mm:ss")
                                          : "—"
                                    color: Theme.text
                                    font.pixelSize: Theme.fsXs
                                    font.family: "Monospace"
                                    Layout.preferredWidth: 160
                                }
                                Label {
                                    text: modelData.channel || "—"
                                    color: typeof fifoChannels !== "undefined"
                                           && fifoChannels.isFifo(modelData.channel || "")
                                           ? Theme.warn : Theme.textMuted
                                    font.pixelSize: Theme.fsXs
                                    font.family: "Monospace"
                                    Layout.preferredWidth: 240
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: modelData.messageId || ""
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fsXs
                                    font.family: "Monospace"
                                    Layout.preferredWidth: 240
                                    elide: Text.ElideMiddle
                                }
                                StatusPill {
                                    visible: !!modelData.replayStatus
                                    status: modelData.replayStatus || ""
                                    requestId: modelData.replayRequestId > 0
                                               ? String(modelData.replayRequestId) : ""
                                }
                                Item { Layout.fillWidth: true }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                ToolTip.text: qsTr("Open headers & payload")
                                ToolTip.visible: containsMouse
                                ToolTip.delay: 600
                                onClicked: root.openDetailsFor(modelData)
                            }
                        }
                    }
                }
            }

            Label {
                visible: !page.inProgress
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Replay is applied in failed_at ASC order — *_errors messages naturally precede mains because they failed first.")
                color: Theme.textMuted
                font.pixelSize: Theme.fsXs
            }
        }
    }
}
