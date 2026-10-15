pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Log rows: level stripe, time, level, service, message (search words
// emphasised). Selection and keyboard moves are reported, not decided here.
ColumnLayout {
    id: root

    property var model                  // LogListModel
    property int currentRow: -1         // selected row (details open)
    property int anchorRow: -1          // emphasised row (focus mode)
    property string serviceTitle: qsTr("Service")
    property var highlightTerms: []
    property bool showService: width >= 640      // narrow results: the service column gives way
    property real newerThanMs: Infinity          // rows after this time arrived with a refresh: green for a moment
    property alias view: list

    signal rowClicked(int row)
    signal moveRequested(int delta)

    spacing: 0

    readonly property int timeWidth: 108
    readonly property int levelWidth: 64
    readonly property int serviceWidth: 120

    // Header
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        color: Theme.bg
        Accessible.role: Accessible.Row
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.borderMuted }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 0
            HeaderText { Layout.preferredWidth: root.timeWidth; text: qsTr("Time") }
            HeaderText { Layout.preferredWidth: root.levelWidth; text: qsTr("Level") }
            HeaderText { Layout.preferredWidth: root.serviceWidth; visible: root.showService; text: root.serviceTitle }
            HeaderText { Layout.fillWidth: true; text: qsTr("Message") }
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.model
        currentIndex: root.currentRow
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        activeFocusOnTab: true
        highlightFollowsCurrentItem: false
        Accessible.role: Accessible.Table
        Accessible.name: qsTr("Logs")
        Keys.onUpPressed: root.moveRequested(-1)
        Keys.onDownPressed: root.moveRequested(1)
        ScrollBar.vertical: ScrollBar { }

        delegate: AbstractButton {
            id: row
            required property int index
            required property string timeText
            required property string level
            required property string service
            required property string message
            required property real timeMs
            readonly property bool fresh: row.timeMs > root.newerThanMs
            readonly property bool selected: row.index === root.currentRow
            readonly property bool anchored: row.index === root.anchorRow
            // One line in the table; the rest of a multi-line message is counted.
            readonly property int firstBreak: row.message.indexOf("
")
            readonly property string firstLine: firstBreak < 0 ? row.message : row.message.slice(0, firstBreak)
            readonly property int moreLines: firstBreak < 0 ? 0 : row.message.split("
").length - 1

            width: ListView.view.width
            height: anchored ? 34 : 28
            focusPolicy: Qt.NoFocus
            hoverEnabled: true
            Accessible.role: Accessible.Row
            Accessible.name: qsTr("%1 %2 %3").arg(row.timeText).arg(row.level).arg(row.message)
            onClicked: { list.forceActiveFocus(); root.rowClicked(row.index) }

            background: Rectangle {
                color: row.selected ? (row.hovered ? Theme.tint(Theme.accent, 0.22) : Theme.accentSoft)
                     : row.anchored ? Theme.tint(Theme.accent, 0.16)
                     : row.fresh ? Theme.successSoft
                     : (row.hovered ? Theme.surface : "transparent")
                Behavior on color { ColorAnimation { duration: 600 } }
                border.width: row.anchored || (row.selected && list.activeFocus) ? 1 : 0
                border.color: Theme.focusRing
                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.surface }
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 4
                    color: row.level !== "" ? Theme.levelColor(row.level) : "transparent"
                }
            }
            contentItem: RowLayout {
                spacing: 0
                Text {
                    Layout.preferredWidth: root.timeWidth
                    Layout.leftMargin: 16
                    text: row.timeText
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: row.anchored ? Theme.textStrong : Theme.textMuted
                }
                Text {
                    Layout.preferredWidth: root.levelWidth
                    text: row.level !== "" ? row.level : "—"
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Medium
                    color: Theme.levelTextColor(row.level)
                }
                Text {
                    Layout.preferredWidth: root.serviceWidth
                    visible: root.showService
                    rightPadding: 8
                    text: row.service
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.accentText
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: 16
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        textFormat: root.highlightTerms.length > 0 ? Text.StyledText : Text.PlainText
                        text: root.highlightTerms.length > 0 ? Session.highlight(row.firstLine, root.highlightTerms, Theme.warnText) : row.firstLine
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: row.anchored ? Theme.textStrong : Theme.text
                    }
                    Rectangle {
                        visible: row.moreLines > 0
                        implicitWidth: moreText.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: Theme.subtle
                        Text {
                            id: moreText
                            anchors.centerIn: parent
                            text: qsTr("↵ +%n line(s)", "", row.moreLines)
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }

    component HeaderText: Text {
        font.family: Theme.sans
        font.pixelSize: Theme.fontXs
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
        color: Theme.textMuted
    }
}
