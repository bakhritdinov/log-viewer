pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Master–detail: the selected entry next to the list (the list keeps its
// scroll position). Message or raw JSON, fields with include/exclude/copy.
Rectangle {
    id: root

    property var entry                  // EntryDetails
    property bool prettyJson: true
    property bool navigable: true
    property bool canOpenFocus: true
    property int tab: 0                 // 0 message + fields, 1 raw JSON (the entry as received)

    signal previousRequested()
    signal nextRequested()
    signal closeRequested()
    signal contextRequested()
    signal traceRequested()
    signal resizeRequested(real width)

    function styled(json) { return Session.jsonStyled(json, Theme.jsonKey, Theme.jsonString, Theme.jsonNumber) }

    implicitWidth: 420
    color: Theme.surface
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Entry details")

    Clipboard { id: clipboard }

    Rectangle { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; width: 1; color: Theme.border }

    // Drag the left edge to make room for long values.
    MouseArea {
        id: resizer
        property real startX
        property real startWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: -3
        width: 6
        z: 2
        cursorShape: Qt.SizeHorCursor
        onPressed: mouse => { startX = mapToItem(null, mouse.x, 0).x; startWidth = root.width }
        onPositionChanged: mouse => {
            if (!pressed) return
            root.resizeRequested(startWidth + startX - mapToItem(null, mouse.x, 0).x)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 1
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.leftMargin: 14
            spacing: 10
            LevelBadge { visible: root.entry.level !== ""; level: root.entry.level }
            Text {
                Layout.fillWidth: true
                text: root.entry.dateTimeText
                elide: Text.ElideRight
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                color: Theme.text
            }
            IconButton { visible: root.navigable; iconName: "chevronUp"; label: qsTr("Previous entry (↑)"); onClicked: root.previousRequested() }
            IconButton { visible: root.navigable; iconName: "chevronDown"; label: qsTr("Next entry (↓)"); onClicked: root.nextRequested() }
            IconButton { iconName: "close"; label: qsTr("Close (Esc)"); onClicked: root.closeRequested() }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

        Flow {
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.leftMargin: 14
            spacing: 6
            AppButton {
                implicitHeight: 28
                iconName: "copy"
                text: root.tab === 1 ? qsTr("Copy JSON") : qsTr("Copy")
                onClicked: clipboard.copy(root.tab === 1 ? root.entry.rawJson : root.entry.message)
            }
            AppButton {
                visible: root.canOpenFocus
                implicitHeight: 28
                iconName: "trace"
                text: qsTr("Trace ±5 min")
                enabled: root.entry.traceId !== ""
                ToolTip.visible: hovered && !enabled
                ToolTip.text: qsTr("The entry has no trace id")
                onClicked: root.traceRequested()
            }
            AppButton {
                visible: root.canOpenFocus
                implicitHeight: 28
                iconName: "clock"
                text: qsTr("Context ±1 min")
                onClicked: root.contextRequested()
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.borderMuted }

        Row {
            Layout.leftMargin: 14
            Layout.topMargin: 8
            spacing: 2
            Accessible.role: Accessible.PageTabList
            Repeater {
                model: [qsTr("Fields"), qsTr("Raw JSON")]
                delegate: AbstractButton {
                    id: tabButton
                    required property int index
                    required property string modelData
                    readonly property bool current: root.tab === tabButton.index
                    implicitHeight: 30
                    implicitWidth: tabLabel.implicitWidth + 24
                    Accessible.role: Accessible.PageTab
                    Accessible.name: tabButton.modelData
                    Accessible.selected: tabButton.current
                    onClicked: root.tab = tabButton.index
                    contentItem: Text {
                        id: tabLabel
                        text: tabButton.modelData
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.Medium
                        color: tabButton.current ? Theme.textStrong : Theme.textMuted
                    }
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 2
                            color: tabButton.current ? Theme.accent : "transparent"
                        }
                    }
                }
            }
        }

        ScrollView {
            visible: root.tab === 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(message.implicitHeight, root.height * 0.4)
            Layout.margins: 14
            Layout.topMargin: 8
            clip: true
            MessageView {
                id: message
                width: root.width - 28
                text: root.prettyJson && root.entry.isJson ? root.entry.prettyMessage : root.entry.message
                richText: root.prettyJson && root.entry.isJson ? root.styled(root.entry.prettyMessage) : ""
            }
        }
        // The whole entry as Grafana sent it, ready to copy and share.
        ScrollView {
            visible: root.tab === 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 14
            Layout.topMargin: 8
            clip: true
            MessageView {
                width: root.width - 28
                text: root.entry.rawJson
                richText: root.styled(root.entry.rawJson)
            }
        }

        RowLayout {
            visible: root.tab === 0
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 6
            SectionLabel { Layout.fillWidth: true; text: qsTr("Fields · %1").arg(root.entry.fields.length) }
            Text {
                text: qsTr("+ include · − exclude")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
        ListView {
            visible: root.tab === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            clip: true
            model: root.entry.fields
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: FieldRow {
                id: field
                required property var modelData
                width: ListView.view.width
                key: modelData.key
                value: modelData.value
                onIncludeRequested: Session.toggleFilter(field.key, field.value, false)
                onExcludeRequested: Session.toggleFilter(field.key, field.value, true)
                onCopyRequested: clipboard.copy(field.value)
            }
        }
    }
}
