pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// One entry on the whole screen: level and time, where it came from, the
// message (pretty JSON or the raw entry, up to 300 px until expanded), copy /
// trace / context, and the fields with + and − (a long press: copy). ⌃ ⌄ or a
// sideways swipe go to the neighbouring entry.
Popup {
    id: root

    signal notice(string text, string actionText, var action)
    signal contextRequested(var model, int row)
    signal traceRequested(var model, int row)
    signal fieldMenuRequested(string key, string value)
    signal filtered()                        // + or − on a field: back to the feed, searching

    property var model                       // a LogListModel
    property int row: -1
    property string backLabel: qsTr("Logs")
    property bool canOpenFocus: true
    property int tab: 0                      // 0 the message, 1 the raw entry
    property bool expanded: false

    readonly property var entry: model && row >= 0 && opened ? Session.detailsOf(model, row) : null
    readonly property bool valid: entry !== null && entry.valid
    readonly property int rows: { void row; return model ? model.rowCount() : 0 }

    function show(listModel, index) {
        model = listModel
        select(index)
        open()
    }
    function select(index) {
        if (!model || index < 0) return
        // The feed shows the loaded entries a part at a time: more as we reach the end.
        if (index >= model.rowCount() && model.canShowMore) model.showMore()
        if (index >= model.rowCount()) return
        row = index
        tab = 0
        expanded = false
        body.contentY = 0
        if (model === Session.logs) Session.selectRow(index)   // a shared link can highlight it
    }
    function styled(json) { return Session.jsonStyled(json, Theme.jsonColors) }

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape
    background: Rectangle { color: Theme.bg }
    enter: Transition { NumberAnimation { property: "x"; from: root.width; to: 0; duration: 160; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "x"; from: 0; to: root.width; duration: 140; easing.type: Easing.InCubic } }

    Clipboard { id: clipboard }
    Timer { id: copiedTimer; interval: 1500 }

    contentItem: ColumnLayout {
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Entry details")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            color: Theme.surface
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 6
                spacing: 4
                BackButton { text: root.backLabel; onClicked: root.close() }
                Item { Layout.fillWidth: true }
                IconButton {
                    touch: true
                    iconName: "chevronUp"
                    label: qsTr("Previous entry")
                    enabled: root.row > 0
                    onClicked: root.select(root.row - 1)
                }
                IconButton {
                    touch: true
                    iconName: "chevronDown"
                    label: qsTr("Next entry")
                    enabled: root.row < root.rows - 1 || (!!root.model && root.model.canShowMore)
                    onClicked: root.select(root.row + 1)
                }
            }
        }

        Flickable {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 32
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            // A sideways swipe: the neighbouring entry.
            DragHandler {
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onActiveChanged: if (!active) {
                    if (translation.x < -80) root.select(root.row + 1)
                    else if (translation.x > 80) root.select(root.row - 1)
                }
            }

            ColumnLayout {
                id: content
                x: 14
                y: 14
                width: body.width - 28
                spacing: 12
                visible: root.valid

                RowLayout {
                    spacing: 10
                    LevelBadge { visible: root.valid && root.entry.level !== ""; level: root.valid ? root.entry.level : "" }
                    Text {
                        text: root.valid ? root.entry.dateTimeText : ""
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontMd
                        color: Theme.text
                    }
                }
                Text {
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    text: "%1 / <font color=\"%2\">%3</font>".arg(Session.namespaceName).arg(Theme.accentText).arg(Session.app)
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    Caption {
                        text: root.valid && root.tab === 0 && !root.entry.isJson
                              ? qsTr("Message · %n line(s)", "", root.entry.message.split("\n").length)
                              : qsTr("Message")
                    }
                    SegmentedControl {
                        compact: false
                        touch: true
                        accessibleName: qsTr("Format")
                        model: [{ label: root.valid && root.entry.isJson ? "JSON" : qsTr("Text"), value: 0 }, { label: "Raw", value: 1 }]
                        value: root.tab
                        onActivated: v => { root.tab = v; root.expanded = false }
                    }
                }
                // Up to 300 px, then "Show all" (opens in place).
                Item {
                    Layout.fillWidth: true
                    implicitHeight: root.expanded ? message.implicitHeight : Math.min(message.implicitHeight, 300)
                    clip: true
                    MessageView {
                        id: message
                        width: parent.width
                        touch: true
                        fontSize: Session.prefs.logFontSize
                        text: !root.valid ? "" : root.tab === 1 ? root.entry.rawJson
                              : Session.prefs.prettyJson && root.entry.isJson ? root.entry.prettyMessage : root.entry.message
                        richText: !root.valid ? "" : root.tab === 1 ? root.styled(root.entry.rawJson)
                                  : Session.prefs.prettyJson && root.entry.isJson ? root.styled(root.entry.prettyMessage) : ""
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 48
                        visible: !root.expanded && message.implicitHeight > 300
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.tint(Theme.bg, 0) }
                            GradientStop { position: 1; color: Theme.bg }
                        }
                    }
                }
                AppButton {
                    Layout.fillWidth: true
                    visible: message.implicitHeight > 300
                    touch: true
                    variant: "ghost"
                    text: root.expanded ? qsTr("Collapse") : qsTr("Show all")
                    onClicked: root.expanded = !root.expanded
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8
                    AppButton {
                        id: copyButton
                        readonly property bool done: copiedTimer.running
                        Layout.fillWidth: true
                        touch: true
                        iconName: done ? "check" : "copy"
                        text: done ? qsTr("Copied") : qsTr("Copy")
                        onClicked: {
                            clipboard.copy(root.tab === 1 ? root.entry.rawJson : root.entry.message)
                            copiedTimer.restart()
                            root.notice(root.tab === 1 ? qsTr("Entry copied") : qsTr("Message copied"), "", null)
                        }
                    }
                    AppButton {
                        Layout.fillWidth: true
                        touch: true
                        iconName: "trace"
                        text: qsTr("Trace")
                        enabled: root.canOpenFocus && root.valid && root.entry.traceId !== ""
                        onClicked: root.traceRequested(root.model, root.row)
                    }
                    AppButton {
                        Layout.fillWidth: true
                        touch: true
                        iconName: "clock"
                        text: qsTr("Context")
                        enabled: root.canOpenFocus
                        onClicked: root.contextRequested(root.model, root.row)
                    }
                }
                // No hover hints on a phone: why a button is off is written out.
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: -4
                    visible: root.canOpenFocus && root.valid && root.entry.traceId === ""
                    text: qsTr("No trace: the entry has no trace_id")
                    wrapMode: Text.Wrap
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.valid && root.entry.fields.length > 0
                    Caption { text: qsTr("Fields · %1").arg(root.valid ? root.entry.fields.length : 0) }
                    Text {
                        text: qsTr("hold to copy")
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.valid && root.entry.fields.length > 0
                    implicitHeight: fieldsColumn.implicitHeight + 2
                    radius: Theme.radiusLg
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.borderMuted
                    clip: true
                    Column {
                        id: fieldsColumn
                        x: 1
                        y: 1
                        width: parent.width - 2
                        Repeater {
                            model: root.valid ? root.entry.fields : []
                            delegate: AbstractButton {
                                id: field
                                required property int index
                                required property var modelData
                                width: fieldsColumn.width
                                height: 56
                                Accessible.name: modelData.key + " " + modelData.value
                                onPressAndHold: root.fieldMenuRequested(modelData.key, modelData.value)
                                background: Rectangle {
                                    color: field.pressed ? Theme.subtle : "transparent"
                                    Rectangle {
                                        visible: field.index > 0
                                        anchors.left: parent.left; anchors.right: parent.right
                                        height: 1
                                        color: Theme.borderMuted
                                    }
                                }
                                contentItem: RowLayout {
                                    spacing: 4
                                    ColumnLayout {
                                        Layout.leftMargin: 12
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: field.modelData.key
                                            elide: Text.ElideRight
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.fontSm
                                            color: Theme.textMuted
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: field.modelData.value
                                            elide: Text.ElideMiddle
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.fontLg
                                            color: Theme.textStrong
                                        }
                                    }
                                    IconButton {
                                        touch: true
                                        iconName: "plus"
                                        iconColor: Theme.accentText
                                        label: qsTr("Show only %1 = %2").arg(field.modelData.key).arg(field.modelData.value)
                                        onClicked: { Session.toggleFilter(field.modelData.key, field.modelData.value, false); root.filtered() }
                                    }
                                    IconButton {
                                        Layout.rightMargin: 4
                                        touch: true
                                        iconName: "minus"
                                        iconColor: Theme.textMuted
                                        label: qsTr("Exclude %1 = %2").arg(field.modelData.key).arg(field.modelData.value)
                                        onClicked: { Session.toggleFilter(field.modelData.key, field.modelData.value, true); root.filtered() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Caption: Text {
        Layout.fillWidth: true
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.7
        font.capitalization: Font.AllUppercase
        color: Theme.textMuted
        elide: Text.ElideRight
    }

    component BackButton: AbstractButton {
        id: back
        implicitHeight: 44
        implicitWidth: backRow.implicitWidth + 14
        Accessible.name: text
        background: Rectangle { radius: Theme.radiusMd; color: back.pressed ? Theme.subtle : "transparent" }
        contentItem: Item {
            Row {
                id: backRow
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                spacing: 2
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronLeft"; size: 20; color: Theme.accentText }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: back.text
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontXl - 1
                    font.weight: Font.Medium
                    color: Theme.accentText
                }
            }
        }
    }
}
