import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// One entry of the feed: level stripe, time, level, how long ago, and the
// message (search words emphasised), a few lines.
AbstractButton {
    id: root

    required property int index
    required property string timeText
    required property string level
    required property string message
    required property real timeMs
    property var highlightTerms: []
    property real nowMs: Date.now()
    property int lines: 3
    // Came with the last refresh: a green glow that fades.
    property bool fresh: false

    // "12 s", "4 min", "2 h", "3 d" since the entry.
    readonly property string ago: {
        const s = Math.max(0, Math.round((nowMs - timeMs) / 1000))
        if (s < 60) return qsTr("%1 s").arg(s)
        if (s < 3600) return qsTr("%1 min").arg(Math.floor(s / 60))
        if (s < 86400) return qsTr("%1 h").arg(Math.floor(s / 3600))
        return qsTr("%1 d").arg(Math.floor(s / 86400))
    }

    implicitHeight: content.implicitHeight + 20
    focusPolicy: Qt.NoFocus
    Accessible.role: Accessible.ListItem
    Accessible.name: qsTr("%1 %2 %3").arg(timeText).arg(level).arg(message)

    background: Rectangle {
        radius: Theme.radiusLg
        color: root.pressed ? Theme.subtle : root.fresh ? Theme.successSoft : Theme.surface
        border.width: 1
        border.color: root.fresh ? Theme.tint(Theme.success, 0.5) : Theme.borderMuted
        Behavior on color { ColorAnimation { duration: 400 } }
        scale: root.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 80 } }
    }

    contentItem: RowLayout {
        id: content
        spacing: 10
        Rectangle {
            Layout.fillHeight: true
            Layout.leftMargin: 10
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            implicitWidth: 3
            radius: 2
            color: root.level !== "" ? Theme.levelColor(root.level) : Theme.border
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            Layout.rightMargin: 12
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: root.timeText
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
                Text {
                    visible: root.level !== ""
                    text: root.level
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    color: Theme.levelTextColor(root.level)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.ago
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
            Text {
                Layout.fillWidth: true
                textFormat: root.highlightTerms.length > 0 ? Text.StyledText : Text.PlainText
                text: root.highlightTerms.length > 0 ? Session.highlight(root.message, root.highlightTerms, Theme.warnText) : root.message
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere   // words stay whole unless one is too long
                maximumLineCount: root.lines
                elide: Text.ElideRight
                lineHeight: 1.3
                font.family: Theme.mono
                font.pixelSize: Session.prefs.logFontSize
                color: Theme.textStrong
            }
        }
    }
}
