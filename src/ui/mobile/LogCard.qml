import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// One entry of the feed: level stripe, time, level, service, how long ago,
// the message (search words emphasised, a few lines) and chosen fields under
// it. Density, tint, level and service follow the preferences.
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
    // The entry a focus is around (blue frame), and the service (trace: entries
    // of several services, so it is always shown).
    property bool anchor: false
    property string service
    // Fields shown under the message: [{ key, value }] (empty values left out).
    property var fields: []
    // Vertical padding from the density.
    readonly property int pad: Session.prefs.density === "compact" ? 6 : Session.prefs.density === "comfortable" ? 14 : 10
    readonly property bool tinted: Session.prefs.tintRows && (level === "ERROR" || level === "WARN")

    // "12 s", "4 min", "2 h", "3 d" since the entry.
    readonly property string ago: {
        const s = Math.max(0, Math.round((nowMs - timeMs) / 1000))
        if (s < 60) return qsTr("%1 s").arg(s)
        if (s < 3600) return qsTr("%1 min").arg(Math.floor(s / 60))
        if (s < 86400) return qsTr("%1 h").arg(Math.floor(s / 3600))
        return qsTr("%1 d").arg(Math.floor(s / 86400))
    }

    implicitHeight: content.implicitHeight + 2 * pad
    focusPolicy: Qt.NoFocus
    Accessible.role: Accessible.ListItem
    Accessible.name: qsTr("%1 %2 %3").arg(timeText).arg(level).arg(message)

    background: Rectangle {
        radius: Theme.radiusLg
        color: root.pressed ? Theme.subtle : root.fresh ? Theme.successSoft : root.anchor ? Theme.accentSoft
             : root.tinted ? Theme.levelSoft(root.level) : Theme.surface
        border.width: root.anchor ? 2 : 1
        border.color: root.anchor ? Theme.accent : root.fresh ? Theme.tint(Theme.success, 0.5) : Theme.borderMuted
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
            Layout.topMargin: root.pad
            Layout.bottomMargin: root.pad
            implicitWidth: 3
            radius: 2
            color: root.level !== "" ? Theme.levelColor(root.level) : Theme.border
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.topMargin: root.pad
            Layout.bottomMargin: root.pad
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
                    visible: root.level !== "" && Session.prefs.showLevel
                    text: root.level
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    color: Theme.levelTextColor(root.level)
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.service !== ""
                    text: root.service
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.accentText
                }
                Item { Layout.fillWidth: true; visible: root.service === "" }
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
            Text {
                Layout.fillWidth: true
                visible: root.fields.length > 0
                textFormat: Text.StyledText
                text: root.fields.map(f => "<font color=\"%1\">%2</font> %3".arg(Theme.textMuted).arg(f.key)
                                                .arg(f.value.replace(/&/g, "&amp;").replace(/</g, "&lt;"))).join("   ")
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                color: Theme.text
            }
        }
    }
}
