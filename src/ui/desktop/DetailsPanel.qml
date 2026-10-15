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

    property real minWidth: 360
    property real maxWidth: 10000
    readonly property bool narrow: width < 400        // shorter button labels

    function styled(json) { return Session.jsonStyled(json, Theme.jsonColors) }

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
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        onPressed: mouse => { startX = mapToItem(null, mouse.x, 0).x; startWidth = root.width }
        onPositionChanged: mouse => {
            if (!pressed) return
            root.resizeRequested(startWidth + startX - mapToItem(null, mouse.x, 0).x)
        }
        onDoubleClicked: root.resizeRequested(420)          // back to the default width
    }
    // The edge while hovered or dragged: blue; yellow at a limit; the width while dragging.
    Rectangle {
        z: 2
        visible: resizer.containsMouse || resizer.pressed
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: 2
        color: root.width <= root.minWidth + 0.5 || root.width >= root.maxWidth - 0.5 ? Theme.warn
             : resizer.pressed ? Theme.accent : Theme.focusRing
    }
    Rectangle {
        z: 3
        visible: resizer.pressed
        x: 10
        y: 10
        implicitWidth: widthText.implicitWidth + 12
        implicitHeight: widthText.implicitHeight + 4
        radius: Theme.radiusSm
        color: Theme.hover
        Text {
            id: widthText
            anchors.centerIn: parent
            text: root.width <= root.minWidth + 0.5 ? qsTr("min. %1").arg(root.minWidth) : qsTr("%1 px").arg(Math.round(root.width))
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
            color: Theme.textStrong
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
                id: copyButton
                implicitHeight: 28
                readonly property bool done: copiedTimer.running
                iconName: done ? "check" : "copy"
                text: done ? qsTr("Copied") : (root.tab === 1 ? qsTr("Copy JSON") : qsTr("Copy"))
                onClicked: { clipboard.copy(root.tab === 1 ? root.entry.rawJson : root.entry.message); copiedTimer.restart() }
                Timer { id: copiedTimer; interval: 1500 }
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: copyButton.done ? Theme.successSoft : (copyButton.hovered ? Theme.hover : Theme.subtle)
                    border.width: 1
                    border.color: copyButton.done ? Theme.successBorder : (copyButton.hovered ? Theme.hoverBorder : Theme.border)
                }
            }
            // A disabled button gets no hover: the reason is shown by its wrapper.
            Item {
                visible: root.canOpenFocus
                implicitWidth: traceButton.implicitWidth
                implicitHeight: traceButton.implicitHeight
                HoverHandler { id: traceHover }
                AppButton {
                    id: traceButton
                    implicitHeight: 28
                    iconName: "trace"
                    text: root.narrow ? qsTr("Trace") : qsTr("Trace ±5 min")
                    enabled: root.entry.traceId !== ""
                    tooltip: root.narrow ? qsTr("Trace ±5 min") : ""
                    onClicked: root.traceRequested()
                }
                AppToolTip {
                    visible: traceHover.hovered && !traceButton.enabled
                    text: qsTr("The entry has no trace_id")
                }
            }
            AppButton {
                visible: root.canOpenFocus
                implicitHeight: 28
                iconName: "clock"
                text: root.narrow ? qsTr("Context") : qsTr("Context ±1 min")
                tooltip: root.narrow ? qsTr("Context ±1 min") : ""
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
                            color: tabButton.current ? Theme.tabIndicator : "transparent"
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
                fontSize: Session.prefs.logFontSize
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
                fontSize: Session.prefs.logFontSize
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
                columnable: true
                isColumn: Session.prefs.extraColumns.indexOf(field.key) >= 0
                onColumnToggled: field.isColumn ? Session.prefs.removeColumn(field.key) : Session.prefs.addColumn(field.key)
            }
        }
    }
}
