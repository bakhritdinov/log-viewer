import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: root
    color: Theme.bgRaised
    border.color: Theme.borderMuted
    border.width: 1

    property string messageId:         ""
    property string failedAt:          ""
    property string channel:           ""
    property string contractId:        ""
    property string payload:           ""
    property string headers:           ""
    property string replayStatus:      ""
    property int    replayRequestId:   0
    property string replayErrorText:   ""
    property string replayProcessedAt: ""

    // Default pretty-print used when something isn't valid JSON or when we
    // need the raw text (e.g. for clipboard copy).
    function prettyJson(s) {
        if (!s) return ""
        try { return JSON.stringify(JSON.parse(s), null, 2) }
        catch (e) { return s }
    }

    // Colorise a JSON string into Qt-rich-text HTML. Uses CSS `white-space`
    // to control wrap — Qt's <pre> always forces no-wrap regardless of the
    // TextEdit.wrapMode property, so we drive layout from the same HTML.
    //   key      → warn (yellow-ish)
    //   string   → success (green)
    //   number   → accent (blue)
    //   bool/null→ Theme.danger / textDim
    function highlightJson(s, wrap) {
        const whitespace = wrap ? "pre-wrap" : "pre"
        if (!s) return ""
        let parsed
        try { parsed = JSON.parse(s) }
        catch (e) {
            return "<div style='white-space:" + whitespace + "; color:"
                   + Theme.text + "'>" + _escapeHtml(s) + "</div>"
        }
        const pretty = _escapeHtml(JSON.stringify(parsed, null, 2))

        const re = /("(\\.|[^"\\])*"\s*:?)|\b(true|false|null)\b|-?\b\d+(?:\.\d+)?(?:[eE][+\-]?\d+)?\b/g
        const colored = pretty.replace(re, function (m) {
            let color = Theme.accent
            if (m[0] === '"') {
                color = /:\s*$/.test(m) ? Theme.warn : Theme.success
            } else if (m === "true" || m === "false") {
                color = Theme.danger
            } else if (m === "null") {
                color = Theme.textDim
            }
            return "<span style='color:" + color + "'>" + m + "</span>"
        })
        return "<div style='margin:0; white-space:" + whitespace + "; word-break:break-all; color:"
               + Theme.text + "'>" + colored + "</div>"
    }

    function _escapeHtml(s) {
        return s.replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
    }

    // Hidden TextEdit used purely to push raw text to the system clipboard
    // — TextEdit.copy() goes through QClipboard, which QML doesn't expose
    // directly in Qt 6.
    TextEdit {
        id: clipboardSink
        visible: false
        readOnly: false
    }
    function copyToClipboard(s) {
        clipboardSink.text = s
        clipboardSink.selectAll()
        clipboardSink.copy()
        clipboardSink.deselect()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp3
        spacing: Theme.sp2

        // ── Metadata strip — hidden until a row is selected ──────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.messageId !== ""
            spacing: Theme.sp3

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: qsTr("Message ID"); color: Theme.textMuted; font.pixelSize: Theme.fsXs }
                TextField {
                    Layout.fillWidth: true
                    text: root.messageId
                    readOnly: true
                    selectByMouse: true
                    font.family: "Monospace"
                    font.pixelSize: Theme.fsSm
                    color: Theme.text
                    background: Rectangle { color: Theme.bgInput; border.color: Theme.border; radius: Theme.rSm }
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 200
                spacing: 2
                Label { text: qsTr("Failed At"); color: Theme.textMuted; font.pixelSize: Theme.fsXs }
                Label {
                    text: root.failedAt || "—"
                    color: Theme.text
                    font.family: "Monospace"
                    font.pixelSize: Theme.fsSm
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 220
                spacing: 2
                Label { text: qsTr("Channel"); color: Theme.textMuted; font.pixelSize: Theme.fsXs }
                Label {
                    text: root.channel || "—"
                    color: Theme.text
                    font.family: "Monospace"
                    font.pixelSize: Theme.fsSm
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 140
                visible: root.contractId !== ""
                spacing: 2
                Label { text: qsTr("Contract"); color: Theme.textMuted; font.pixelSize: Theme.fsXs }
                Label {
                    text: root.contractId
                    color: Theme.text
                    font.family: "Monospace"
                    font.pixelSize: Theme.fsSm
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 200
                visible: root.replayStatus !== ""
                spacing: 2
                Label { text: qsTr("Replay request"); color: Theme.textMuted; font.pixelSize: Theme.fsXs }
                StatusPill {
                    status: root.replayStatus
                    requestId: root.replayRequestId > 0
                               ? String(root.replayRequestId) : ""
                }
            }
        }

        // ── Worker error banner (only for failed replays) ────────────────────
        // When the worker tried this message and it threw again, surface the
        // exception text here so the operator doesn't have to dig through
        // ecotone_replay_requests by hand.
        Rectangle {
            id: replayErrorBanner
            visible: root.messageId !== "" && root.replayStatus === "failed"
                     && root.replayErrorText !== ""
            Layout.fillWidth: true
            implicitHeight: replayErrorCol.implicitHeight + Theme.sp3 * 2
            color: Qt.rgba(0.97, 0.32, 0.29, 0.10)
            border.color: Theme.danger
            border.width: 1
            radius: Theme.rSm

            ColumnLayout {
                id: replayErrorCol
                anchors.fill: parent
                anchors.margins: Theme.sp3
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp2
                    Label {
                        text: "⚠"
                        color: Theme.danger
                        font.pixelSize: Theme.fsLg
                        font.bold: true
                    }
                    Label {
                        text: qsTr("Replay request #%1 failed").arg(root.replayRequestId)
                        color: Theme.danger
                        font.pixelSize: Theme.fsSm
                        font.bold: true
                    }
                    Label {
                        visible: root.replayProcessedAt !== ""
                        text: qsTr("· at %1").arg(root.replayProcessedAt)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsXs
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: qsTr("⧉ Copy")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsXs
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyToClipboard(root.replayErrorText)
                        }
                    }
                }
                TextEdit {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(implicitHeight, 110)
                    text: root.replayErrorText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    font.family: "Monospace"
                    font.pixelSize: Theme.fsXs
                    color: Theme.text
                }
            }
        }

        // ── Empty-state placeholder ─────────────────────────────────────────
        Item {
            visible: root.messageId === ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.sp2
                Label {
                    text: "↑"
                    color: Theme.textDim
                    font.pixelSize: 36
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: qsTr("Select a message above to view its headers and payload")
                    color: Theme.textDim
                    font.pixelSize: Theme.fsSm
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ── Side-by-side headers + payload ──────────────────────────────────
        // SplitView state — only the Headers width is persisted because the
        // Payload panel always fills the remainder. Saved on debounce so a
        // resize-drag doesn't spam QSettings on every pixel.
        SplitView {
            id: contentSplit
            visible: root.messageId !== ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            JsonPanel {
                id: headersPanel
                SplitView.preferredWidth: typeof ecotoneConfig !== "undefined" && ecotoneConfig !== null
                                          ? ecotoneConfig.columnWidth("detailsHeadersWidth", 360)
                                          : 360
                SplitView.minimumWidth: 220
                title: qsTr("Headers")
                accent: Theme.accent
                rawJson: root.headers
                onWidthChanged: {
                    if (contentSplit.visible && width > 0) saveWidthTimer.restart()
                }
            }

            JsonPanel {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 280
                title: qsTr("Payload")
                accent: Theme.success
                rawJson: root.payload
            }

            // Debounce QSettings writes — the splitter drag emits many
            // widthChanged ticks per second.
            Timer {
                id: saveWidthTimer
                interval: 500
                repeat: false
                onTriggered: {
                    if (typeof ecotoneConfig === "undefined" || ecotoneConfig === null) return
                    if (headersPanel.width <= 0) return
                    ecotoneConfig.setColumnWidth("detailsHeadersWidth", headersPanel.width)
                }
            }
        }
    }

    // One reusable panel = title bar + Copy/Wrap toolbar + scrollable JSON
    // body with syntax-highlighted output.
    component JsonPanel : Rectangle {
        id: panel
        property string title: ""
        property color  accent: Theme.textMuted
        property string rawJson: ""
        property bool   wrap: false  // off by default — JSON usually fits horizontally

        color: Theme.bgInput
        border.color: Theme.borderMuted
        border.width: 1
        radius: Theme.rSm

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Title bar + actions.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                color: Theme.bgSubtle
                topLeftRadius: Theme.rSm
                topRightRadius: Theme.rSm
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp3
                    anchors.rightMargin: Theme.sp2
                    spacing: Theme.sp2
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: panel.accent
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Label {
                        text: panel.title
                        color: Theme.text
                        font.pixelSize: Theme.fsSm
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    // Tiny action icons — keep label minimal so we don't crowd.
                    SmallIcon {
                        text: panel.wrap ? "↩" : "→"
                        tooltip: panel.wrap ? qsTr("Disable wrap") : qsTr("Wrap long lines")
                        onClicked: panel.wrap = !panel.wrap
                    }
                    SmallIcon {
                        text: "⧉"
                        tooltip: qsTr("Copy pretty-printed JSON to clipboard")
                        onClicked: {
                            root.copyToClipboard(root.prettyJson(panel.rawJson))
                            copiedFlash.start()
                        }
                    }
                    Label {
                        id: copiedLabel
                        text: qsTr("Copied!")
                        color: Theme.success
                        font.pixelSize: Theme.fsXs
                        opacity: 0
                        SequentialAnimation {
                            id: copiedFlash
                            NumberAnimation { target: copiedLabel; property: "opacity"; to: 1.0; duration: 120 }
                            PauseAnimation  { duration: 900 }
                            NumberAnimation { target: copiedLabel; property: "opacity"; to: 0.0; duration: 250 }
                        }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            }

            // Body — scrollable, syntax-highlighted JSON. TextEdit with
            // RichText format renders the <span style="color:…">…</span>
            // markup produced by highlightJson().
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                TextEdit {
                    text: root.highlightJson(panel.rawJson, panel.wrap)
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.RichText
                    // Wrap is actually driven by `white-space` in the HTML —
                    // see highlightJson(). TextEdit.wrapMode is set in sync
                    // so non-styled fallback text wraps too.
                    wrapMode: panel.wrap ? TextEdit.Wrap : TextEdit.NoWrap
                    font.family: "Monospace"
                    font.pixelSize: Theme.fsSm
                    color: Theme.text
                    padding: Theme.sp2
                }
            }
        }
    }

    // Tiny ghost button used in panel toolbars. Renders as a single glyph
    // with a hover background.
    component SmallIcon : Rectangle {
        id: icon
        property string text: ""
        property string tooltip: ""
        signal clicked()
        implicitWidth: 22
        implicitHeight: 22
        radius: Theme.rSm
        color: mouse.containsMouse ? Theme.bgHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        Label {
            anchors.centerIn: parent
            text: icon.text
            color: Theme.text
            font.pixelSize: Theme.fsMd
        }
        ToolTip.text: icon.tooltip
        ToolTip.visible: tooltip !== "" && mouse.containsMouse
        ToolTip.delay: 400
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: icon.clicked()
        }
    }
}
