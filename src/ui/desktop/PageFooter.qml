import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Paging over the loaded entries ([ ] keys), loading progress, a stopped load
// that can continue, and "load more" from the server. Narrow: short labels.
Rectangle {
    id: root

    readonly property var logs: Session.logs
    readonly property bool compact: width < 720
    readonly property bool stopped: Session.loadStopped && !Session.loading

    function num(n) { return n.toLocaleString(Qt.locale(), "f", 0) }

    implicitHeight: 44
    color: Theme.bg

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.borderMuted }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 10 : 16
        anchors.rightMargin: root.compact ? 10 : 16
        spacing: root.compact ? 8 : 12

        Icon {
            visible: root.stopped
            name: "pause"
            size: 12
            strokeWidth: 3
            color: Theme.warnText
        }
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: {
                const strong = s => "<font color=\"%1\">%2</font>".arg(Theme.text).arg(s)
                if (Session.loading) {
                    if (root.logs.loadedCount === 0)
                        return qsTr("Requesting entries for “%1”…").arg(Session.timeRangeLabel)
                    return qsTr("Loaded %1 entries…").arg(strong(root.num(root.logs.loadedCount)))
                }
                if (root.stopped)
                    return qsTr("Stopped at %1 entries · the period has more").arg(root.num(root.logs.loadedCount))
                if (root.logs.totalCount === 0) return ""
                const a = strong(root.num(root.logs.firstRowNumber))
                const b = strong(root.num(root.logs.lastRowNumber))
                const n = strong(root.num(root.logs.totalCount))
                if (root.compact) return qsTr("%1–%2 / %3").arg(a).arg(b).arg(n)
                if (Session.hasMore) return qsTr("Showing %1–%2 of %3 loaded · the period has more").arg(a).arg(b).arg(n)
                if (root.logs.pageCount > 1) return qsTr("Showing %1–%2 of %3 · all entries of the period").arg(a).arg(b).arg(n)
                return qsTr("Showing %1–%2 of %3").arg(a).arg(b).arg(n)
            }
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: root.stopped ? Theme.warnText : Theme.textMuted
        }

        Row {
            visible: root.logs.pageCount > 1
            spacing: 4
            IconButton {
                visible: !root.compact
                iconName: "chevronsLeft"; label: qsTr("First page"); shortcut: "Shift+["
                enabled: root.logs.page > 0
                onClicked: root.logs.goToPage(0)
            }
            IconButton {
                iconName: "chevronLeft"; label: qsTr("Newer"); shortcut: "["
                enabled: root.logs.page > 0
                onClicked: root.logs.goToPage(root.logs.page - 1)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.compact
                text: qsTr("Page")
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textMuted
            }
            AppTextField {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.compact
                implicitWidth: 48
                implicitHeight: 28
                horizontalAlignment: TextInput.AlignHCenter
                mono: true
                text: root.logs.page + 1
                validator: IntValidator { bottom: 1; top: root.logs.pageCount }
                Accessible.name: qsTr("Page number")
                onAccepted: root.logs.goToPage(Number(text) - 1)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.compact ? "%1/%2".arg(root.logs.page + 1).arg(root.logs.pageCount)
                                   : qsTr("of %1").arg(root.logs.pageCount)
                font.family: root.compact ? Theme.mono : Theme.sans
                font.pixelSize: root.compact ? Theme.fontSm : Theme.fontMd
                color: Theme.textMuted
            }
            IconButton {
                iconName: "chevronRight"; label: qsTr("Older"); shortcut: "]"
                enabled: root.logs.page < root.logs.pageCount - 1
                onClicked: root.logs.goToPage(root.logs.page + 1)
            }
            IconButton {
                visible: !root.compact
                iconName: "chevronsRight"; label: qsTr("Last page"); shortcut: "Shift+]"
                enabled: root.logs.page < root.logs.pageCount - 1
                onClicked: root.logs.goToPage(root.logs.pageCount - 1)
            }
        }

        AppButton {
            id: stopButton
            visible: Session.loading
            text: qsTr("Stop")
            Accessible.name: text
            contentItem: Row {
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: stopButton.text
                    font: stopButton.font
                    color: stopButton._fg
                }
                Kbd { anchors.verticalCenter: parent.verticalCenter; text: "Esc" }
            }
            onClicked: Session.stopLoading()
        }
        AppButton {
            visible: root.stopped
            text: qsTr("Continue loading")
            onClicked: Session.loadMore()
        }
        AppButton {
            visible: Session.hasMore && !Session.loading && !root.stopped
            implicitHeight: root.compact ? 28 : Theme.controlHeight
            text: root.compact ? qsTr("%1 more").arg(root.num(Session.loadStep))
                               : qsTr("Load %1 more").arg(root.num(Session.loadStep))
            onClicked: Session.loadMore()
        }
    }
}
