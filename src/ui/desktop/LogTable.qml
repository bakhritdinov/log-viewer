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
    // Narrow results: the service column gives way; the preferences can hide it too.
    property bool showService: width >= 640 && Session.prefs.showService
    property bool showLevel: Session.prefs.showLevel
    property real newerThanMs: Infinity          // rows after this time arrived with a refresh: green for a moment
    property alias view: list

    signal rowClicked(int row)
    signal moveRequested(int delta)

    spacing: 0

    // Text size, row height and time format come from the preferences; the
    // columns are measured for them — by Text items laid out exactly as the
    // cells (FontMetrics came out narrower on a scaled Windows screen and the
    // time ran into the level).
    readonly property int fontSize: Session.prefs.logFontSize
    readonly property int lines: Session.prefs.messageLines
    readonly property var extraColumns: Session.prefs.extraColumns
    Text {
        id: timeProbe
        visible: false
        text: Session.prefs.timeFormat === "s" ? "00:00:00" : Session.prefs.timeFormat === "date" ? "00 MMM. 00:00:00" : "00:00:00.000"
        font.family: Theme.mono
        font.pixelSize: root.fontSize
    }
    Text {
        id: levelProbe
        visible: false
        text: "ERROR"
        font.family: Theme.mono
        font.pixelSize: root.fontSize
        font.weight: Font.Medium
    }
    // Wide enough for the value and for the column title ("УРОВЕНЬ" is wider than "ERROR").
    readonly property int timeWidth: Math.max(Math.ceil(timeProbe.implicitWidth) + 16, Math.ceil(timeHeader.implicitWidth) + 12)
    readonly property int levelWidth: Math.max(Math.ceil(levelProbe.implicitWidth) + 22, Math.ceil(levelHeader.implicitWidth) + 12)
    readonly property int serviceWidth: Math.round(120 * fontSize / 12)
    readonly property int extraWidth: Math.round(140 * fontSize / 12)

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
            HeaderText { id: timeHeader; Layout.preferredWidth: root.timeWidth; text: qsTr("Time") }
            HeaderText { id: levelHeader; Layout.preferredWidth: root.levelWidth; visible: root.showLevel; text: qsTr("Level") }
            HeaderText { Layout.preferredWidth: root.serviceWidth; visible: root.showService; text: root.serviceTitle }
            Repeater {
                model: root.extraColumns
                delegate: HeaderText {
                    required property string modelData
                    Layout.preferredWidth: root.extraWidth
                    rightPadding: 8
                    text: modelData
                    elide: Text.ElideRight
                    font.capitalization: Font.MixedCase
                }
            }
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
            // One line in the table: every line of the message, " ↵ " between them, elided.
            required property string oneLine
            required property int moreLines

            // Taller for wrapped messages; the anchored row (focus mode) a bit taller still.
            width: ListView.view.width
            height: Math.max(Session.prefs.rowHeight, root.lines > 1 ? messageText.implicitHeight + 10 : 0) + (anchored ? 6 : 0)
            focusPolicy: Qt.NoFocus
            hoverEnabled: true
            Accessible.role: Accessible.Row
            Accessible.name: qsTr("%1 %2 %3").arg(row.timeText).arg(row.level).arg(row.message)
            onClicked: { list.forceActiveFocus(); root.rowClicked(row.index) }

            background: Rectangle {
                color: row.selected ? (row.hovered ? Theme.tint(Theme.accent, 0.22) : Theme.accentSoft)
                     : row.anchored ? Theme.tint(Theme.accent, 0.16)
                     : row.fresh ? Theme.successSoft
                     : row.hovered ? Theme.surface
                     : Session.prefs.tintRows && (row.level === "ERROR" || row.level === "WARN") ? Theme.tint(Theme.levelColor(row.level), Theme.dark ? 0.08 : 0.11)
                     : "transparent"
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
                    font.pixelSize: root.fontSize
                    color: row.anchored ? Theme.textStrong : Theme.textMuted
                }
                Text {
                    Layout.preferredWidth: root.levelWidth
                    visible: root.showLevel
                    text: row.level !== "" ? row.level : "—"
                    font.family: Theme.mono
                    font.pixelSize: root.fontSize
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
                    font.pixelSize: root.fontSize
                    color: Theme.accentText
                }
                Repeater {
                    model: root.extraColumns
                    delegate: Text {
                        required property string modelData
                        Layout.preferredWidth: root.extraWidth
                        rightPadding: 8
                        text: root.model ? root.model.fieldText(row.index, modelData) : ""
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: root.fontSize
                        color: Theme.text
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: 16
                    spacing: 8
                    Text {
                        id: messageText
                        readonly property string shown: root.lines > 1 ? row.message : row.oneLine
                        Layout.fillWidth: true
                        textFormat: root.highlightTerms.length > 0 ? Text.StyledText : Text.PlainText
                        text: root.highlightTerms.length > 0 ? Session.highlight(shown, root.highlightTerms, Theme.warnText) : shown
                        elide: Text.ElideRight
                        wrapMode: root.lines > 1 ? Text.WrapAnywhere : Text.NoWrap
                        maximumLineCount: root.lines
                        font.family: Theme.mono
                        font.pixelSize: root.fontSize
                        color: row.anchored ? Theme.textStrong : Theme.text
                    }
                    Rectangle {
                        visible: row.moreLines > 0 && root.lines === 1
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
