pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Similar WARN and ERROR messages grouped (numbers, ids, times become *): a
// card per pattern with its count and share; tapping opens the variable
// values and the actions. Counting while the first batch loads; nothing to
// group or all one-offs explained.
Item {
    id: root

    signal notice(string text, string actionText, var action)

    property int openIndex: -1
    Connections {
        target: Session
        function onPatternsChanged() { root.openIndex = -1 }
    }

    function num(n) { return n.toLocaleString(Qt.locale(), "f", 0) }
    function styledTemplate(parts) {
        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        return parts.map(esc).join("<font color=\"%1\">*</font>".arg(Theme.variable))
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: Session.patterns.count > 0
        topMargin: 4
        bottomMargin: 12
        leftMargin: 12
        rightMargin: 12
        spacing: 8
        clip: true
        model: Session.patterns
        Accessible.role: Accessible.List
        Accessible.name: qsTr("Patterns")

        header: Column {
            width: ListView.view.width - 24
            bottomPadding: 8
            spacing: 6
            Text {
                width: parent.width
                text: qsTr("Similar WARN and ERROR messages, from %1 loaded entries.").arg(root.num(Session.logs.totalCount))
                      + (Session.hiddenSinglePatterns > 0 && !Session.showSinglePatterns
                         ? " " + qsTr("%n one-off message(s) not shown.", "", Session.hiddenSinglePatterns) : "")
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            AppButton {
                visible: Session.hiddenSinglePatterns > 0 || Session.showSinglePatterns
                variant: "link"
                text: Session.showSinglePatterns ? qsTr("Hide one-offs") : qsTr("Show one-offs")
                onClicked: Session.showSinglePatterns = !Session.showSinglePatterns
            }
        }

        delegate: AbstractButton {
            id: pattern
            required property int index
            required property var templateParts
            required property string level
            required property int count
            required property real share
            required property var examples
            readonly property bool open: root.openIndex === index
            width: ListView.view.width - 24
            implicitHeight: column.implicitHeight + 24
            Accessible.name: qsTr("%1 entries: %2").arg(count).arg(templateParts.join("*"))
            onClicked: root.openIndex = open ? -1 : index
            background: Rectangle {
                radius: Theme.radiusLg
                color: pattern.pressed ? Theme.subtle : Theme.surface
                border.width: 1
                border.color: pattern.open ? Theme.accent : Theme.borderMuted
            }
            contentItem: Item {
                ColumnLayout {
                    id: column
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: root.num(pattern.count)
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.DemiBold
                            color: Theme.textStrong
                        }
                        Text {
                            text: pattern.level
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.DemiBold
                            color: Theme.levelTextColor(pattern.level)
                        }
                        // Share of the loaded entries.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 4
                            radius: 2
                            color: Theme.subtle
                            Rectangle {
                                width: parent.width * Math.min(1, pattern.share)
                                height: parent.height
                                radius: 2
                                color: Theme.levelColor(pattern.level)
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        textFormat: Text.StyledText
                        text: root.styledTemplate(pattern.templateParts)
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: pattern.open ? 12 : 3
                        elide: Text.ElideRight
                        lineHeight: 1.3
                        font.family: Theme.mono
                        font.pixelSize: Session.prefs.logFontSize
                        color: Theme.text
                    }
                    // Opened: the variable values and what to do with the pattern.
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: pattern.open
                        spacing: 6
                        Repeater {
                            model: pattern.open ? pattern.examples : []
                            delegate: Text {
                                id: example
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                text: "*%1  %2".arg(example.index + 1).arg(example.modelData.join(" · "))
                                elide: Text.ElideRight
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontSm
                                color: Theme.textMuted
                            }
                        }
                        AppButton {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            touch: true
                            variant: "primary"
                            text: qsTr("Show %n entries", "", pattern.count)
                            onClicked: { Session.showPattern(pattern.index, false); Session.patternsEnabled = false }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8
                            AppButton {
                                Layout.fillWidth: true
                                touch: true
                                iconName: "copy"
                                text: qsTr("Copy")
                                onClicked: { clipboard.copy(pattern.templateParts.join("*")); root.notice(qsTr("Pattern copied"), "", null) }
                            }
                            AppButton {
                                Layout.fillWidth: true
                                touch: true
                                text: qsTr("Exclude")
                                onClicked: { Session.showPattern(pattern.index, true); Session.patternsEnabled = false }
                            }
                        }
                    }
                }
            }
        }
    }

    // Counting while the first batch loads.
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        topPadding: 4
        spacing: 8
        visible: Session.patterns.count === 0 && (Session.loading || Session.analyzing)
        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("Counting patterns")
        Repeater {
            model: [0.8, 0.6, 0.7]
            delegate: Rectangle {
                id: skeleton
                required property real modelData
                width: parent.width
                height: 88
                radius: Theme.radiusLg
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderMuted
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Rectangle { width: 90; height: 10; radius: Theme.radiusSm; color: Theme.subtle }
                    Rectangle { width: parent.width * skeleton.modelData; height: 10; radius: Theme.radiusSm; color: Theme.subtle }
                    Rectangle { width: parent.width * skeleton.modelData * 0.6; height: 10; radius: Theme.radiusSm; color: Theme.subtle }
                }
            }
        }
    }

    // Nothing to group, or every warning and error is a one-off.
    EmptyState {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        anchors.verticalCenter: parent.verticalCenter
        visible: Session.patterns.count === 0 && !Session.loading && !Session.analyzing
        touch: true
        iconName: Session.hiddenSinglePatterns > 0 ? "logs" : "check"
        title: Session.hiddenSinglePatterns > 0 ? qsTr("All messages differ")
                                                 : qsTr("No WARN or ERROR among the loaded entries")
        message: Session.hiddenSinglePatterns > 0
                 ? qsTr("All %n warnings and errors occur once.", "", Session.hiddenSinglePatterns)
                 : qsTr("Patterns are built from warnings and errors only.")
        AppButton {
            width: parent ? parent.width : 0
            visible: Session.hiddenSinglePatterns > 0
            touch: true
            variant: "primary"
            text: qsTr("Show one-offs")
            onClicked: Session.showSinglePatterns = true
        }
        AppButton {
            width: parent ? parent.width : 0
            touch: true
            text: qsTr("To the entries")
            onClicked: Session.patternsEnabled = false
        }
    }

    Clipboard { id: clipboard }
}
