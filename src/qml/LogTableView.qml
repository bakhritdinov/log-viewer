import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: tableRoot
    color: Theme.bg
    border.color: Theme.border
    border.width: 1

    signal traceRequested(string traceId)
    signal firstPageRequested()
    signal prevPageRequested()
    signal nextPageRequested()
    signal lastPageRequested()
    signal loadMoreRequested()

    property int currentPage: 0
    property int maxPage: 1
    property bool hasMore: false
    property var searchTerms: []

    // Field-name overrides — passed in from AppContent so we can show the actual app/service
    // label discovered from Loki/VictoriaLogs (e.g. `_appName`, `service`, `app`, `job`).
    property string serviceField: "service"

    // Set by AppContent while chained batches are still arriving — list freezes its scroll
    // and key navigation so jitter from rapid model resets doesn't disorient the user.
    property bool chainLoading: false

    // Normalize free-form level strings (case- and synonym-insensitive) into a few buckets.
    function _normalizeLevel(level) {
        if (!level) return ""
        let l = String(level).toUpperCase().trim()
        if (l === "ERR" || l === "ERROR" || l === "FATAL" || l === "CRIT" || l === "CRITICAL" || l === "PANIC") return "ERROR"
        if (l === "WARN" || l === "WARNING") return "WARN"
        if (l === "INFO" || l === "NOTICE" || l === "INFORMATION") return "INFO"
        if (l === "DEBUG" || l === "DBG") return "DEBUG"
        if (l === "TRACE") return "TRACE"
        return ""
    }
    function _levelColor(key) {
        switch (key) {
            case "ERROR": return Theme.levelError
            case "WARN":  return Theme.levelWarn
            case "INFO":  return Theme.levelInfo
            case "DEBUG": return Theme.levelDebug
            case "TRACE": return Theme.levelTrace
        }
        return Theme.text
    }
    function _levelTint(key) {
        switch (key) {
            case "ERROR": return Qt.rgba(0.973, 0.318, 0.286, 0.10)
            case "WARN":  return Qt.rgba(0.824, 0.600, 0.133, 0.10)
            case "INFO":  return Qt.rgba(0.345, 0.654, 1.0, 0.06)
            case "DEBUG": return Qt.rgba(0.545, 0.580, 0.620, 0.06)
            case "TRACE": return Qt.rgba(0.430, 0.470, 0.510, 0.05)
        }
        return "transparent"
    }

    // True if the user wants pretty-printed JSON in the expanded message card.
    // Persists for the session — reset on next launch.
    property bool prettyMessage: true

    // If `text` parses as JSON, return a 2-space indented form. Otherwise the original.
    function prettyFormat(text) {
        if (!text) return ""
        let trimmed = String(text).trim()
        if (trimmed.length < 2) return text
        let first = trimmed[0]
        if (first !== "{" && first !== "[") return text
        try {
            return JSON.stringify(JSON.parse(trimmed), null, 2)
        } catch (e) {
            return text
        }
    }

    // True only if the message would actually format differently when prettified.
    function isPrettifiable(text) {
        if (!text) return false
        let trimmed = String(text).trim()
        if (trimmed.length < 2) return false
        let first = trimmed[0]
        if (first !== "{" && first !== "[") return false
        try { JSON.parse(trimmed); return true } catch (e) { return false }
    }

    // Wrap matched substrings in a HTML span so they're tinted with the accent color.
    // Caller must use textFormat: Text.RichText.
    function highlightMatches(text, terms) {
        let html = String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
        if (!terms || terms.length === 0) return html
        let pattern = terms
            .map(t => t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
            .filter(t => t !== "")
            .join("|")
        if (pattern === "") return html
        let re = new RegExp("(" + pattern + ")", "gi")
        return html.replace(re, '<span style="background-color:' + Theme.accent + '33; color:' + Theme.accent + ';">$1</span>')
    }

    // Adaptive column widths.
    readonly property bool showService: tableRoot.width >= 900
    readonly property bool compactTime: tableRoot.width < 1100
    readonly property bool wrapMessage: tableRoot.width < 1100

    // User-resizable; initial values fall back to adaptive defaults the first time.
    property int timeWidth: (typeof configManager !== "undefined" && configManager !== null)
        ? configManager.columnWidth("time", compactTime ? 92 : 180)
        : (compactTime ? 92 : 180)
    property int levelWidth: (typeof configManager !== "undefined" && configManager !== null)
        ? configManager.columnWidth("level", 78) : 78
    property int serviceWidth: (typeof configManager !== "undefined" && configManager !== null)
        ? configManager.columnWidth("service", 150) : 150

    onTimeWidthChanged:    if (typeof configManager !== "undefined" && configManager !== null) configManager.setColumnWidth("time", timeWidth)
    onLevelWidthChanged:   if (typeof configManager !== "undefined" && configManager !== null) configManager.setColumnWidth("level", levelWidth)
    onServiceWidthChanged: if (typeof configManager !== "undefined" && configManager !== null) configManager.setColumnWidth("service", serviceWidth)

    // Reset expansion when the model changes (e.g. page or filter switch).
    Connections {
        target: logModel
        function onCountChanged() { logList.expandedIndex = -1 }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Sticky header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.hHeader
            color: Theme.bgRaised
            z: 2

            Row {
                anchors.fill: parent
                HeaderLabel { width: 22; showSeparator: false }
                HeaderLabel { text: "Time"; width: tableRoot.timeWidth }
                HeaderLabel { text: "Level"; width: tableRoot.levelWidth }
                HeaderLabel { visible: tableRoot.showService; text: "Service"; width: tableRoot.showService ? tableRoot.serviceWidth : 0 }
                HeaderLabel {
                    text: "Message"
                    showSeparator: false
                    width: parent.width - 22 - tableRoot.timeWidth - tableRoot.levelWidth
                         - (tableRoot.showService ? tableRoot.serviceWidth : 0)
                }
            }

            // Resize handles overlay — exactly on column boundaries, don't change Row layout.
            ResizeHandle {
                x: 22 + tableRoot.timeWidth - 3
                height: parent.height
                onMoved: (delta) => tableRoot.timeWidth = Math.max(60, Math.min(360, tableRoot.timeWidth + delta))
            }
            ResizeHandle {
                x: 22 + tableRoot.timeWidth + tableRoot.levelWidth - 3
                height: parent.height
                onMoved: (delta) => tableRoot.levelWidth = Math.max(50, Math.min(180, tableRoot.levelWidth + delta))
            }
            ResizeHandle {
                visible: tableRoot.showService
                x: 22 + tableRoot.timeWidth + tableRoot.levelWidth + tableRoot.serviceWidth - 3
                height: parent.height
                onMoved: (delta) => tableRoot.serviceWidth = Math.max(60, Math.min(360, tableRoot.serviceWidth + delta))
            }

            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Skeleton placeholder shown during the first load (or when changing
            // page/filter and the model is briefly empty). Hidden as soon as rows arrive.
            Column {
                anchors.fill: parent
                spacing: 1
                visible: typeof logModel !== "undefined" && logModel !== null
                       && logModel.loading && logList.count === 0
                Repeater {
                    model: 14
                    SkeletonRow { width: parent.width; seed: (index * 0.137) % 1.0 }
                }
            }

        ListView {
            id: logList
            anchors.fill: parent
            model: logModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            focus: true
            // Freeze scroll/keyboard while batches still streaming in — prevents the
            // visual jitter from each appendEntries → applySlice cycle.
            interactive: !tableRoot.chainLoading
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            // j/k or arrow keys navigate; Enter toggles row expansion.
            Keys.onPressed: (event) => {
                if (count === 0) return
                if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    if (currentIndex < count - 1) currentIndex++
                    else currentIndex = 0
                    event.accepted = true
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    if (currentIndex > 0) currentIndex--
                    else currentIndex = count - 1
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (currentIndex < 0) currentIndex = 0
                    expandedIndex = (expandedIndex === currentIndex) ? -1 : currentIndex
                    event.accepted = true
                }
            }
            cacheBuffer: 200

            // Index of the currently expanded row, or -1 if none.
            property int expandedIndex: -1

            delegate: Item {
                id: rowItem
                width: ListView.view.width
                height: header.height + (expanded ? detailsLoader.implicitHeight : 0)

                property bool   expanded: logList.expandedIndex === index
                property string itemLevelRaw: (typeof fields !== "undefined" && fields !== null)
                    ? (fields.level || fields.severity || fields.lvl || fields.loglevel || fields.log_level || "")
                    : ""
                readonly property string itemLevel: tableRoot._normalizeLevel(rowItem.itemLevelRaw)
                property string itemService: (typeof fields !== "undefined" && fields !== null)
                    ? (fields[tableRoot.serviceField] || fields.service || fields.app || fields._appName || fields.job || fields.kubernetes_pod_name || "")
                    : ""
                property string traceId: (typeof fields !== "undefined" && fields !== null) ? (fields.traceId || fields.trace_id || "") : ""
                property var    fieldsObj: (typeof fields !== "undefined" && fields !== null) ? fields : ({})
                readonly property color levelTint: tableRoot._levelTint(itemLevel)
                readonly property color levelColor: tableRoot._levelColor(itemLevel)

                // No height animation: animating delegate height pushes every row below
                // through a continuous reposition, which makes the list re-render every
                // frame and look like flicker. Instant expand is cleaner.

                // ── Header row ─────────────────────────────────────────────
                Rectangle {
                    id: header
                    width: parent.width
                    height: Math.max(Theme.hRow, messageText.implicitHeight + Theme.sp1 * 2)
                    color: rowItem.expanded ? Theme.bgRaised
                         : rowMouse.containsMouse ? Theme.rowHover
                         : rowItem.levelTint
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }

                    // Level accent line
                    Rectangle {
                        width: 3
                        height: parent.height
                        color: rowItem.itemLevel === "" ? "transparent" : rowItem.levelColor
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp2
                        anchors.rightMargin: Theme.sp2

                        // Expand chevron
                        Item {
                            width: 22
                            height: parent.height
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: Theme.sp1
                                text: rowItem.expanded ? "▾" : "▸"
                                color: rowItem.expanded ? Theme.accent : Theme.textMuted
                                font.pixelSize: Theme.fsMd
                            }
                        }

                        LogText {
                            text: tableRoot.compactTime ? timestamp.split(" ")[1].slice(0, 8) : timestamp
                            width: tableRoot.timeWidth
                            color: Theme.textMuted
                            font.family: "Monospace"
                        }

                        // Level chip
                        Item {
                            width: tableRoot.levelWidth
                            height: parent.height
                            Rectangle {
                                visible: rowItem.itemLevel !== ""
                                anchors.top: parent.top
                                anchors.topMargin: Theme.sp1 + 1
                                anchors.left: parent.left; anchors.leftMargin: Theme.sp1
                                width: chipText.implicitWidth + Theme.sp2 * 2
                                height: 18
                                radius: 9
                                color: Qt.rgba(rowItem.levelColor.r, rowItem.levelColor.g, rowItem.levelColor.b, 0.18)
                                border.color: rowItem.levelColor
                                border.width: 1
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: rowItem.itemLevel
                                    color: rowItem.levelColor
                                    font.pixelSize: Theme.fsXs
                                    font.bold: true
                                    font.letterSpacing: 0.4
                                }
                            }
                        }

                        LogText {
                            visible: tableRoot.showService
                            text: rowItem.itemService
                            width: tableRoot.showService ? tableRoot.serviceWidth : 0
                            color: Theme.text
                        }

                        LogText {
                            id: messageText
                            text: tableRoot.searchTerms.length > 0
                                ? tableRoot.highlightMatches(message.replace(/\n/g, " "), tableRoot.searchTerms)
                                : message.replace(/\n/g, " ")
                            textFormat: tableRoot.searchTerms.length > 0 ? Text.RichText : Text.PlainText
                            width: header.width - 22 - tableRoot.timeWidth - tableRoot.levelWidth
                                 - (tableRoot.showService ? tableRoot.serviceWidth : 0)
                                 - Theme.sp4
                            color: Theme.text
                            clip: true
                            elide: Text.ElideRight
                            wrapMode: tableRoot.wrapMessage ? Text.Wrap : Text.NoWrap
                            maximumLineCount: tableRoot.wrapMessage ? 2 : 1

                            HoverHandler { id: msgHover }
                            ToolTip.visible: msgHover.hovered && messageText.truncated
                            ToolTip.text: message
                            ToolTip.delay: 500
                        }
                    }

                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.borderMuted; opacity: 0.4 }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !tableRoot.chainLoading
                        cursorShape: tableRoot.chainLoading ? Qt.WaitCursor : Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton && rowItem.traceId !== "") {
                                contextMenu.currentTraceId = rowItem.traceId
                                contextMenu.popup()
                                return
                            }
                            logList.expandedIndex = rowItem.expanded ? -1 : index
                        }
                    }
                }

                // ── Expansion (lazy) ───────────────────────────────────────
                Loader {
                    id: detailsLoader
                    anchors.top: header.bottom
                    width: rowItem.width
                    active: rowItem.expanded
                    visible: rowItem.expanded
                    sourceComponent: detailsComponent
                }

                // Component lives inside the delegate so it can resolve `message`,
                // model role properties, and rowItem ids through proper scope.
                Component {
                    id: detailsComponent

                    Rectangle {
                        width: detailsLoader.width
                        color: Theme.bgRaised
                        border.color: Theme.border
                        border.width: 1
                        implicitHeight: detailsCol.implicitHeight + Theme.sp4 * 2

                        ColumnLayout {
                            id: detailsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.sp4
                            spacing: Theme.sp3

                            // Message card with internal scroll for long stacktraces.
                            // Uses bgSubtle so it stands apart from the bgInput-colored field cards below.
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(msgEdit.implicitHeight + Theme.sp3 * 2, 280)
                                color: Theme.bgSubtle
                                border.color: Theme.borderMuted
                                border.width: 1
                                radius: Theme.rMd
                                clip: true

                                // Quote-style accent stripe on the left edge.
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    color: Theme.accent
                                    opacity: 0.6
                                }

                                Flickable {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.sp3 + 4 // leave room for accent stripe
                                    anchors.topMargin: Theme.sp3
                                    anchors.bottomMargin: Theme.sp3
                                    anchors.rightMargin: Theme.sp3 + 28 // leave room for copy button
                                    contentWidth: width
                                    contentHeight: msgEdit.implicitHeight
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                    TextEdit {
                                        id: msgEdit
                                        width: parent.width
                                        // Body text: pretty-printed JSON when applicable, else raw.
                                        // Highlight pass runs on top of either form.
                                        readonly property string _displayText:
                                            tableRoot.prettyMessage ? tableRoot.prettyFormat(message) : message
                                        text: tableRoot.searchTerms.length > 0
                                            ? tableRoot.highlightMatches(_displayText, tableRoot.searchTerms)
                                            : _displayText
                                        textFormat: tableRoot.searchTerms.length > 0 ? TextEdit.RichText : TextEdit.PlainText
                                        color: Theme.text
                                        font.family: "Monospace"
                                        font.pixelSize: Theme.fsMd
                                        readOnly: true
                                        wrapMode: TextEdit.Wrap
                                        selectByMouse: true
                                        selectionColor: Theme.accent
                                        selectedTextColor: Theme.textOnAccent
                                    }
                                }

                                Row {
                                    anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: Theme.sp1
                                    spacing: 2

                                    IconButton {
                                        visible: tableRoot.isPrettifiable(message)
                                        text: "{ }"
                                        tooltipText: tableRoot.prettyMessage ? "Show raw JSON" : "Pretty-print JSON"
                                        pixel: Theme.fsSm
                                        boxSize: 24
                                        active: tableRoot.prettyMessage
                                        onClicked: tableRoot.prettyMessage = !tableRoot.prettyMessage
                                    }
                                    IconButton {
                                        text: "📋"
                                        tooltipText: "Copy message"
                                        pixel: Theme.fsSm
                                        boxSize: 24
                                        onClicked: {
                                            tempArea.text = msgEdit._displayText
                                            tempArea.selectAll()
                                            tempArea.copy()
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "FIELDS"
                                    color: Theme.textMuted
                                    font.bold: true
                                    font.pixelSize: Theme.fsXs
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: 0.5
                                }
                                Badge { text: rowItem.fieldsObj ? Object.keys(rowItem.fieldsObj).length : 0 }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.sp1
                                Repeater {
                                    model: rowItem.fieldsObj ? Object.keys(rowItem.fieldsObj).sort() : []
                                    delegate: Rectangle {
                                        id: fieldDelegate
                                        Layout.fillWidth: true
                                        implicitHeight: fieldGrid.implicitHeight + Theme.sp3 * 2
                                        color: fieldMouse.containsMouse ? Theme.rowHover : Theme.bgInput
                                        border.color: fieldMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                        border.width: 1
                                        radius: Theme.rMd
                                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.dFast } }

                                        property string fieldKey: modelData
                                        property string fieldVal: (typeof logModel !== "undefined" && logModel !== null && rowItem.fieldsObj)
                                            ? logModel.formatValue(rowItem.fieldsObj[modelData])
                                            : ""
                                        readonly property bool stacked: width < 560

                                        MouseArea { id: fieldMouse; anchors.fill: parent; hoverEnabled: true }

                                        GridLayout {
                                            id: fieldGrid
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.leftMargin: Theme.sp3
                                            anchors.rightMargin: Theme.sp2
                                            anchors.topMargin: Theme.sp3
                                            anchors.bottomMargin: Theme.sp3
                                            columns: fieldDelegate.stacked ? 2 : 3
                                            columnSpacing: Theme.sp3
                                            rowSpacing: Theme.sp2

                                            Text {
                                                text: fieldDelegate.fieldKey
                                                color: Theme.accent
                                                font.pixelSize: Theme.fsMd
                                                font.bold: true
                                                font.family: "Monospace"
                                                // Wide layout keeps the 180px "column" baseline so short keys still align
                                                // visually, but long keys grow up to ~45% of the row and wrap instead of
                                                // eliding -- so the full key is always readable.
                                                Layout.minimumWidth: fieldDelegate.stacked ? 0 : 180
                                                Layout.maximumWidth: fieldDelegate.stacked ? -1 : Math.max(180, fieldDelegate.width * 0.45)
                                                Layout.fillWidth: fieldDelegate.stacked
                                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                            }

                                            // When stacked, actions sit on the same row as the key.
                                            // When wide, actions go after the value as usual.
                                            Row {
                                                visible: fieldDelegate.stacked
                                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                                spacing: 2
                                                IconButton {
                                                    text: "🔍"; tooltipText: "Toggle filter"
                                                    pixel: Theme.fsSm; boxSize: 24
                                                    onClicked: window.toggleFilter(fieldDelegate.fieldKey, rowItem.fieldsObj[fieldDelegate.fieldKey])
                                                }
                                                IconButton {
                                                    text: "📋"; tooltipText: "Copy value"
                                                    pixel: Theme.fsSm; boxSize: 24
                                                    onClicked: { tempArea.text = fieldDelegate.fieldVal; tempArea.selectAll(); tempArea.copy() }
                                                }
                                            }

                                            Text {
                                                text: fieldDelegate.fieldVal
                                                color: Theme.text
                                                font.pixelSize: Theme.fsMd
                                                font.family: "Monospace"
                                                Layout.fillWidth: true
                                                Layout.columnSpan: fieldDelegate.stacked ? 2 : 1
                                                Layout.alignment: Qt.AlignTop
                                                wrapMode: Text.Wrap
                                            }

                                            Row {
                                                visible: !fieldDelegate.stacked
                                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                                spacing: 2
                                                IconButton {
                                                    text: "🔍"; tooltipText: "Toggle filter"
                                                    pixel: Theme.fsSm; boxSize: 24
                                                    onClicked: window.toggleFilter(fieldDelegate.fieldKey, rowItem.fieldsObj[fieldDelegate.fieldKey])
                                                }
                                                IconButton {
                                                    text: "📋"; tooltipText: "Copy value"
                                                    pixel: Theme.fsSm; boxSize: 24
                                                    onClicked: { tempArea.text = fieldDelegate.fieldVal; tempArea.selectAll(); tempArea.copy() }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        } // end of body Item (skeleton + ListView)

        PageBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            currentPage: tableRoot.currentPage
            maxPage: tableRoot.maxPage
            logCount: (typeof logModel !== "undefined" && logModel !== null) ? logModel.totalCount : 0
            busy: typeof logModel !== "undefined" && logModel !== null && logModel.loading
            hasMore: tableRoot.hasMore
            onFirstClicked: tableRoot.firstPageRequested()
            onPrevClicked:  tableRoot.prevPageRequested()
            onNextClicked:  tableRoot.nextPageRequested()
            onLastClicked:  tableRoot.lastPageRequested()
            onLoadMoreClicked: tableRoot.loadMoreRequested()
        }
    }

    Menu {
        id: contextMenu
        property string currentTraceId: ""
        background: Rectangle { color: Theme.bgRaised; border.color: Theme.border; border.width: 1; radius: Theme.rMd }
        MenuItem {
            text: "Fetch Trace Context (±5m)"
            onTriggered: traceRequested(contextMenu.currentTraceId)
            contentItem: Text { text: parent.text; color: Theme.text; padding: Theme.sp1; font.pixelSize: Theme.fsSm }
            background: Rectangle { color: parent.highlighted ? Theme.bgSubtle : "transparent"; radius: Theme.rSm }
        }
    }

    TextArea { id: tempArea; visible: false }

    component HeaderLabel : Rectangle {
        property alias text: lbl.text
        property bool showSeparator: true
        height: parent.height
        color: "transparent"
        Text {
            id: lbl
            anchors.left: parent.left; anchors.leftMargin: Theme.sp3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textMuted
            font.bold: true
            font.pixelSize: Theme.fsXs
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.5
        }
        Rectangle {
            visible: parent.showSeparator
            anchors.right: parent.right
            height: parent.height * 0.5
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            color: Theme.border
        }
    }

    component ResizeHandle : Item {
        signal moved(int delta)
        width: 6
        height: parent ? parent.height : 24

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height * 0.5
            color: handleMouse.containsMouse || handleMouse.pressed ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.dFast } }
        }

        MouseArea {
            id: handleMouse
            anchors.fill: parent
            anchors.leftMargin: -3
            anchors.rightMargin: -3
            cursorShape: Qt.SplitHCursor
            hoverEnabled: true
            property real lastX: 0
            onPressed: (mouse) => { lastX = mouse.x }
            onPositionChanged: (mouse) => {
                if (!pressed) return
                let delta = mouse.x - lastX
                if (delta !== 0) {
                    parent.moved(delta)
                    // lastX stays at original press point — Row recomputes layout each tick.
                }
            }
        }
    }

    component LogText : Text {
        font.pixelSize: Theme.fsMd
        verticalAlignment: tableRoot.wrapMessage ? Text.AlignTop : Text.AlignVCenter
        elide: Text.ElideRight
        leftPadding: Theme.sp2
        topPadding: Theme.sp1
        maximumLineCount: 1
        wrapMode: Text.NoWrap
    }
}
