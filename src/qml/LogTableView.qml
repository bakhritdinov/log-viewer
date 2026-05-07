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

    property int currentPage: 0
    property int maxPage: 1

    // Adaptive column widths.
    readonly property bool showService: tableRoot.width >= 900
    readonly property bool compactTime: tableRoot.width < 1100
    readonly property bool wrapMessage: tableRoot.width < 1100
    readonly property int  timeWidth: compactTime ? 92 : 180
    readonly property int  levelWidth: 78
    readonly property int  serviceWidth: 150

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
                HeaderLabel { width: 22 }
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
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        ListView {
            id: logList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: logModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            cacheBuffer: 200

            // Index of the currently expanded row, or -1 if none.
            property int expandedIndex: -1

            delegate: Item {
                id: rowItem
                width: ListView.view.width
                height: header.height + (expanded ? detailsLoader.implicitHeight : 0)

                property bool   expanded: logList.expandedIndex === index
                property string itemLevel: (typeof fields !== "undefined" && fields !== null) ? (fields.level || "") : ""
                property string itemService: (typeof fields !== "undefined" && fields !== null) ? (fields.service || "") : ""
                property string traceId: (typeof fields !== "undefined" && fields !== null) ? (fields.traceId || fields.trace_id || "") : ""
                property var    fieldsObj: (typeof fields !== "undefined" && fields !== null) ? fields : ({})
                readonly property color levelTint: itemLevel === "ERROR" ? Qt.rgba(0.973, 0.318, 0.286, 0.10)
                                                : itemLevel === "WARN"  ? Qt.rgba(0.824, 0.600, 0.133, 0.10)
                                                : "transparent"

                Behavior on height { NumberAnimation { duration: Theme.dBase; easing.type: Easing.InOutCubic } }

                // ── Header row ─────────────────────────────────────────────
                Rectangle {
                    id: header
                    width: parent.width
                    height: Math.max(Theme.hRow, messageText.implicitHeight + Theme.sp1 * 2)
                    color: rowItem.expanded ? Theme.bgRaised
                         : rowMouse.containsMouse ? Theme.bgRaised
                         : rowItem.levelTint
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }

                    // Level accent line
                    Rectangle {
                        width: 3
                        height: parent.height
                        color: rowItem.itemLevel === "ERROR" ? Theme.danger
                             : rowItem.itemLevel === "WARN"  ? Theme.warn
                             : "transparent"
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
                                color: rowItem.itemLevel === "ERROR" ? Qt.rgba(0.973, 0.318, 0.286, 0.18)
                                     : rowItem.itemLevel === "WARN"  ? Qt.rgba(0.824, 0.600, 0.133, 0.18)
                                     : Theme.bgSubtle
                                border.color: rowItem.itemLevel === "ERROR" ? Theme.danger
                                            : rowItem.itemLevel === "WARN"  ? Theme.warn
                                            : Theme.borderMuted
                                border.width: 1
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: rowItem.itemLevel
                                    color: rowItem.itemLevel === "ERROR" ? Theme.danger
                                         : rowItem.itemLevel === "WARN"  ? Theme.warn
                                         : Theme.text
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
                            text: message.replace(/\n/g, " ")
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
                        cursorShape: Qt.PointingHandCursor
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
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(msgEdit.implicitHeight + Theme.sp3 * 2, 280)
                                color: Theme.bgInput
                                border.color: Theme.borderMuted
                                border.width: 1
                                radius: Theme.rMd
                                clip: true

                                Flickable {
                                    anchors.fill: parent
                                    anchors.margins: Theme.sp3
                                    anchors.rightMargin: Theme.sp3 + 28 // leave room for copy button
                                    contentWidth: width
                                    contentHeight: msgEdit.implicitHeight
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                    TextEdit {
                                        id: msgEdit
                                        width: parent.width
                                        text: message
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

                                IconButton {
                                    anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: Theme.sp1
                                    text: "📋"
                                    tooltipText: "Copy message"
                                    pixel: Theme.fsSm
                                    boxSize: 24
                                    onClicked: {
                                        tempArea.text = message
                                        tempArea.selectAll()
                                        tempArea.copy()
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
                                        color: fieldMouse.containsMouse ? Theme.bgSubtle : Theme.bgInput
                                        border.color: fieldMouse.containsMouse ? Theme.border : Theme.borderMuted
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
                                                Layout.preferredWidth: fieldDelegate.stacked ? -1 : 180
                                                Layout.fillWidth: fieldDelegate.stacked
                                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                                                elide: Text.ElideRight
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

        // ── Pagination bar ─────────────────────────────────────────────────
        Rectangle {
            id: pageBar
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: Theme.bgRaised

            readonly property bool busy: typeof logModel !== "undefined" && logModel !== null && logModel.loading

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }

            BusyIndicator {
                anchors.left: parent.left; anchors.leftMargin: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                running: pageBar.busy
                visible: running
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.sp1

                PageButton {
                    text: "«"
                    ToolTip.visible: hovered; ToolTip.text: "First page"; ToolTip.delay: 400
                    enabled: tableRoot.currentPage > 0 && !pageBar.busy
                    onClicked: tableRoot.firstPageRequested()
                }
                PageButton {
                    text: "‹ Newer"
                    enabled: tableRoot.currentPage > 0 && !pageBar.busy
                    onClicked: tableRoot.prevPageRequested()
                }

                Rectangle {
                    Layout.leftMargin: Theme.sp2
                    Layout.rightMargin: Theme.sp2
                    implicitWidth: pageLabel.implicitWidth + Theme.sp3 * 2
                    implicitHeight: 24
                    color: Theme.bgInput
                    border.color: Theme.borderMuted
                    border.width: 1
                    radius: 12
                    Text {
                        id: pageLabel
                        anchors.centerIn: parent
                        text: `Page ${tableRoot.currentPage + 1} of ${tableRoot.maxPage}`
                        color: Theme.text
                        font.pixelSize: Theme.fsXs
                        font.bold: true
                    }
                }

                PageButton {
                    text: "Older ›"
                    enabled: tableRoot.currentPage + 1 < tableRoot.maxPage && !pageBar.busy
                    onClicked: tableRoot.nextPageRequested()
                }
                PageButton {
                    text: "»"
                    ToolTip.visible: hovered; ToolTip.text: "Last page"; ToolTip.delay: 400
                    enabled: tableRoot.currentPage + 1 < tableRoot.maxPage && !pageBar.busy
                    onClicked: tableRoot.lastPageRequested()
                }
            }

            Row {
                anchors.right: parent.right; anchors.rightMargin: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp1
                Badge { text: (typeof logModel !== "undefined" && logModel !== null) ? logModel.count : 0; labelColor: Theme.text }
                Text {
                    text: "logs"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsXs
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
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
