import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Item {
    id: root

    // Selected-row outputs (consumed by EcotoneDetailsPane).
    property string selectedMessageId:        ""
    property string selectedFailedAt:         ""
    property string selectedChannel:          ""
    property string selectedContractId:       ""
    property string selectedPayload:          ""
    property string selectedHeaders:          ""
    property string selectedReplayStatus:     ""
    property int    selectedReplayRequestId:  0

    // Bound by the window — disables channel section headers while a search
    // is active because backend ORDER BY then sorts by match-priority
    // instead of by channel, which would otherwise produce fragmented groups.
    property bool groupByChannel: true

    // Replay-one bubbles up; FIFO channels handle replay through the
    // "Replay by contract" dialog in the window header.
    signal replayOneRequested(string messageId)

    readonly property int colFailedWidth:    190
    readonly property int colIdWidth:        280
    readonly property int colActWidth:       110

    // Table header strip — columns are arranged after the section header
    // (channel) is rendered as a separate row in the ListView, so the table
    // itself doesn't need a Channel column.
    Rectangle {
        id: headerStrip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.hHeader
        color: Theme.bgRaised

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp3
            spacing: 0

            ColHeader { width: root.colFailedWidth; text: qsTr("Failed At")  }
            ColHeader { width: root.colIdWidth;     text: qsTr("Message ID") }
            ColHeader { text: qsTr("Payload")
                        width: list.width
                               - root.colFailedWidth
                               - root.colIdWidth
                               - root.colActWidth
                               - Theme.sp3 }
            ColHeader { width: root.colActWidth; text: qsTr("Action") }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    }

    component ColHeader : Item {
        property alias text: lbl.text
        height: parent.height
        Label {
            id: lbl
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Theme.sp2
            color: Theme.textMuted
            font.pixelSize: Theme.fsSm
            font.bold: true
            elide: Text.ElideRight
        }
    }

    ListView {
        id: list
        anchors.top: headerStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: typeof errorMessagesModel !== "undefined" ? errorMessagesModel : null
        currentIndex: -1
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        // Section headers group rows by channel — the model returns rows
        // already ordered by channel ASC. Disabled while searching so
        // payload-priority ordering doesn't fragment the visual groups.
        section.property: root.groupByChannel ? "channel" : ""
        section.criteria: ViewSection.FullString
        section.delegate: Rectangle {
            width: list.width
            height: 28
            color: Theme.bgSubtle
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: typeof fifoChannels !== "undefined" && fifoChannels.isFifo(section || "")
                           ? Theme.warn : Theme.accent
                }
                Label {
                    text: section || qsTr("(no channel)")
                    font.pixelSize: Theme.fsSm
                    font.family: "Monospace"
                    font.bold: true
                    color: Theme.text
                }
                Label {
                    visible: typeof fifoChannels !== "undefined" && fifoChannels.isFifo(section || "")
                    text: qsTr("FIFO per contract — use \"Replay by contract\" in the toolbar")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsXs
                }
            }
        }

        delegate: Rectangle {
            id: row
            width: list.width
            height: Theme.hRow + 6
            color: ListView.isCurrentItem
                   ? Theme.rowHover
                   : (index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02))

            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.borderMuted }

            // Row-selection MouseArea declared FIRST so it sits *below* the
            // Row + SmallButton(s) in z order. Children of Row with their own
            // MouseArea (the per-row Replay button) hit-test first and stop
            // propagation to this fallback selection handler.
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    list.currentIndex = index
                    root.selectedMessageId       = messageId
                    root.selectedFailedAt        = failedAt
                    root.selectedChannel         = channel
                    root.selectedContractId     = contractId
                    root.selectedPayload         = payload
                    root.selectedHeaders         = headers
                    root.selectedReplayStatus    = replayStatus
                    root.selectedReplayRequestId = replayRequestId
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp3
                spacing: 0

                Label {
                    width: root.colFailedWidth
                    height: parent.height
                    text: failedAt
                    font.pixelSize: Theme.fsSm
                    font.family: "Monospace"
                    color: Theme.text
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Label {
                    width: root.colIdWidth
                    height: parent.height
                    text: messageId
                    font.pixelSize: Theme.fsSm
                    font.family: "Monospace"
                    color: Theme.text
                    elide: Text.ElideMiddle
                    verticalAlignment: Text.AlignVCenter
                }
                Label {
                    width: list.width
                           - root.colFailedWidth
                           - root.colIdWidth
                           - root.colActWidth
                           - Theme.sp3
                    height: parent.height
                    text: payload
                    font.pixelSize: Theme.fsSm
                    color: Theme.text
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Item {
                    width: root.colActWidth
                    height: parent.height
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.sp2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp1

                        // Non-FIFO rows: a regular replay button.
                        // Disabled while a previous request is still pending /
                        // processing — protects against duplicate sends.
                        SmallButton {
                            visible: !isFifoQueue
                            text: replayStatus === "pending" || replayStatus === "processing"
                                  ? replayStatus
                                  : qsTr("Replay")
                            tone: "primary"
                            enabled: replayStatus !== "pending" && replayStatus !== "processing"
                            tooltip: enabled
                                     ? qsTr("Replay this single message")
                                     : qsTr("Already queued (status: %1) — wait for worker").arg(replayStatus)
                            onClicked: {
                                console.log(">>> QML SmallButton.onClicked for", messageId)
                                root.replayOneRequested(messageId)
                            }
                        }
                        // FIFO rows: disabled chip; route through Replay by contract.
                        SmallButton {
                            visible: isFifoQueue
                            text: qsTr("FIFO")
                            tone: "secondary"
                            enabled: false
                            tooltip: qsTr("Use “Replay by contract” in the toolbar — FIFO channels must replay every message of a contract together.")
                        }
                    }
                }
            }

        }

        // Empty-state overlay.
        Item {
            anchors.fill: parent
            visible: list.count === 0
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.sp3
                Label {
                    text: typeof errorMessagesModel !== "undefined" && errorMessagesModel !== null && errorMessagesModel.total === 0
                          ? "✓"
                          : "—"
                    color: Theme.textMuted
                    font.pixelSize: 48
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: typeof errorMessagesModel !== "undefined" && errorMessagesModel !== null && errorMessagesModel.total === 0
                          ? qsTr("No error messages match the current filter.")
                          : qsTr("No data loaded yet. Configure DB connection in Settings, then press Refresh.")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsMd
                    Layout.alignment: Qt.AlignHCenter
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: 360
                }
            }
        }
    }

    // Reusable compact button used in the Action column. enabled / opacity are
    // driven by the inherited Item.enabled — no redeclaration of `enabled`
    // because that shadows the base property and breaks click propagation.
    component SmallButton : Rectangle {
        id: smallBtn
        property string text: ""
        property string tone: "secondary"
        property string tooltip: ""
        signal clicked()

        implicitHeight: 22
        implicitWidth: btnLabel.implicitWidth + Theme.sp3
        radius: Theme.rSm
        color: !smallBtn.enabled ? Theme.bgSubtle
                                : (tone === "primary"
                                   ? (mouseArea.containsMouse ? Theme.success : Theme.successDim)
                                   : (mouseArea.containsMouse ? Theme.bgHover : Theme.bgSubtle))
        border.color: !smallBtn.enabled ? Theme.borderMuted
                                       : (tone === "primary" ? Theme.success : Theme.border)
        border.width: 1
        opacity: smallBtn.enabled ? 1.0 : 0.5
        Behavior on color { ColorAnimation { duration: Theme.dFast } }

        Label {
            id: btnLabel
            anchors.centerIn: parent
            text: smallBtn.text
            color: smallBtn.tone === "primary" && smallBtn.enabled ? Theme.textOnAccent : Theme.text
            font.pixelSize: Theme.fsXs
            font.bold: true
        }

        ToolTip.text: smallBtn.tooltip
        ToolTip.visible: smallBtn.tooltip !== "" && mouseArea.containsMouse
        ToolTip.delay: 400

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: smallBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                console.log(">>> SmallButton MouseArea onClicked (enabled=" + smallBtn.enabled + ", text=" + smallBtn.text + ")")
                smallBtn.clicked()
            }
        }
    }
}
