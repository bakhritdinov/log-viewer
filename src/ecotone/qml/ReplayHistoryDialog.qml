import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

// Audit-style view over the last N rows of ecotone_replay_requests. Read-only.
// Refreshes on open and on demand via the Refresh button — not on a timer
// (the operator usually wants a stable snapshot to read).
Dialog {
    id: root
    title: qsTr("Replay history")
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 980
    height: 620

    property string envName: ""
    property int    limit:   200
    property var    rows:    []
    property bool   loading: false

    background: Rectangle {
        color: Theme.bgRaised
        border.color: Theme.border
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
            Text { text: "⌛"; color: Theme.accent; font.pixelSize: Theme.fsXl; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.title; color: Theme.text; font.pixelSize: Theme.fsLg; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    }

    Connections {
        target: typeof ecotoneClient !== "undefined" ? ecotoneClient : null
        ignoreUnknownSignals: true
        function onReplayHistoryReceived(list) {
            if (!root.visible) return
            root.rows = list
            root.loading = false
        }
        function onErrorOccurred(_) {
            // EcotoneWindow's footer already surfaces the message; we just
            // release the loading flag so the Refresh button is interactive.
            if (root.visible) root.loading = false
        }
    }

    function refresh() {
        if (typeof ecotoneClient === "undefined" || ecotoneClient === null) return
        root.loading = true
        ecotoneClient.fetchReplayHistory(root.limit)
    }

    onAboutToShow: {
        rows = []
        refresh()
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── Column header strip ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.hHeader
            color: Theme.bgInput
            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp3
                anchors.rightMargin: Theme.sp3
                spacing: 0
                HCol { width: 72;  text: qsTr("ID") }
                HCol { width: 100; text: qsTr("Status") }
                HCol { width: 160; text: qsTr("Failed At") }
                HCol { width: 160; text: qsTr("Processed At") }
                HCol { width: 240; text: qsTr("Message ID") }
                HCol { text: qsTr("Error / Reason"); width: list.width
                                                                  - 72 - 100 - 160 - 160 - 240 - Theme.sp3 }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        component HCol : Item {
            property alias text: lbl.text
            height: parent.height
            Label {
                id: lbl
                anchors.fill: parent
                anchors.rightMargin: Theme.sp2
                verticalAlignment: Text.AlignVCenter
                color: Theme.textMuted
                font.pixelSize: Theme.fsXs
                font.bold: true
                elide: Text.ElideRight
            }
        }

        // ── Rows ────────────────────────────────────────────────────────
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            // Recycle delegate instances on scroll instead of destroying and
            // re-creating them — without this, scrolling 200 rows containing
            // multi-kB error_text fields causes multi-second hitches because
            // each off-screen delegate fully tears down and a new one is
            // built (with all 5 Labels laid out from scratch) as it appears.
            reuseItems: true
            // 12000 px covers the entire 200-row list at row-height ~34, so
            // ListView creates every delegate once on dialog-open and any
            // scroll afterwards is pure paint — no rebind hitch.
            cacheBuffer: 12000
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                width: list.width
                height: Theme.hRow + 6
                color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.borderMuted }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp3
                    spacing: 0
                    Label {
                        width: 72
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: "#" + modelData.id
                        color: Theme.text
                        font.pixelSize: Theme.fsSm
                        font.family: "Monospace"
                    }
                    Item {
                        width: 100
                        height: parent.height
                        StatusPill {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            status: modelData.status || ""
                        }
                    }
                    Label {
                        width: 160
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.failedAt || "—"
                        color: Theme.text
                        font.pixelSize: Theme.fsSm
                        font.family: "Monospace"
                        elide: Text.ElideRight
                    }
                    Label {
                        width: 160
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.processedAt || "—"
                        color: modelData.processedAt && modelData.processedAt !== "—"
                               ? Theme.text : Theme.textDim
                        font.pixelSize: Theme.fsSm
                        font.family: "Monospace"
                        elide: Text.ElideRight
                    }
                    Label {
                        width: 240
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.messageId || "—"
                        color: Theme.textDim
                        font.pixelSize: Theme.fsSm
                        font.family: "Monospace"
                        elide: Text.ElideMiddle
                    }
                    Label {
                        width: list.width - 72 - 100 - 160 - 160 - 240 - Theme.sp3
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        // errorText is already pre-truncated to ≤300 chars
                        // in C++ (EcotoneClient::fetchReplayHistory).
                        text: modelData.errorText || ""
                        color: modelData.status === "failed" ? Theme.danger : Theme.textMuted
                        font.pixelSize: Theme.fsSm
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        textFormat: Text.PlainText
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: !root.loading && root.rows.length === 0
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.sp2
                    Label {
                        text: "—"
                        color: Theme.textMuted
                        font.pixelSize: 36
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: qsTr("No replay requests yet.")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsSm
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: root.loading
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Loading…")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsSm
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
                text: root.envName
                      ? qsTr("Env: %1 · %2 row(s)").arg(root.envName).arg(root.rows.length)
                      : qsTr("%1 row(s)").arg(root.rows.length)
                color: Theme.textMuted
                font.pixelSize: Theme.fsSm
            }
            Item { Layout.fillWidth: true }
            SecondaryButton {
                text: qsTr("Refresh")
                enabled: !root.loading
                onClicked: root.refresh()
            }
            PrimaryButton {
                text: qsTr("Close")
                Layout.preferredWidth: 110
                onClicked: root.accept()
            }
        }
    }
}
