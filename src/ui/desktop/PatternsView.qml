pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Similar messages grouped: numbers, ids, addresses and times replaced by "*".
// A row opens to show the variable values and to narrow or exclude the pattern.
ColumnLayout {
    id: root

    property int openIndex: -1

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 16
        Layout.topMargin: 10
        Layout.bottomMargin: 10
        spacing: 12
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Similar WARN and ERROR messages are grouped: numbers, ids, addresses and times become *. Based on %1 loaded entries.")
                  .arg(Session.logs.totalCount.toLocaleString(Qt.locale(), "f", 0))
                  + (Session.hiddenSinglePatterns > 0
                     ? " " + qsTr("%n one-off message(s) not shown.", "", Session.hiddenSinglePatterns) : "")
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }
        Text {
            text: qsTr("Sort")
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }
        AppButton {
            id: sortButton
            readonly property var options: [
                { label: qsTr("by count"), value: "count" },
                { label: qsTr("by first appearance"), value: "first" },
                { label: qsTr("by level"), value: "level" },
            ]
            text: options.find(o => o.value === Session.patternSort).label
            Accessible.name: qsTr("Sort patterns: %1").arg(text)
            onClicked: sortMenu.open()
            contentItem: Row {
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sortButton.text
                    font: sortButton.font
                    color: Theme.text
                }
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronDown"; size: 12; color: Theme.textMuted }
            }
            AppMenu {
                id: sortMenu
                y: sortButton.height + 4
                x: sortButton.width - width
                Repeater {
                    model: sortButton.options
                    delegate: AppMenuItem {
                        required property var modelData
                        text: modelData.label
                        checkedMark: Session.patternSort === modelData.value
                        onTriggered: Session.patternSort = modelData.value
                    }
                }
            }
        }
    }

    // Header
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        color: Theme.bg
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.borderMuted }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.borderMuted }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            HeaderText { Layout.preferredWidth: 56; text: qsTr("Count") }
            HeaderText { Layout.preferredWidth: 72; text: qsTr("Share", "column: share of entries") }
            HeaderText { Layout.preferredWidth: 56; text: qsTr("Level") }
            HeaderText { Layout.fillWidth: true; text: qsTr("Pattern") }
            HeaderText { Layout.preferredWidth: 96; text: qsTr("Trend") }
            HeaderText { Layout.preferredWidth: 72; text: qsTr("Last") }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: Session.patterns
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }

        delegate: Column {
            id: pattern
            required property int index
            required property var templateParts
            required property string level
            required property int count
            required property real share
            required property string lastSeen
            required property var examples
            required property var trend
            required property int trendMax
            readonly property bool open: root.openIndex === pattern.index

            width: ListView.view.width

            AbstractButton {
                id: header
                width: parent.width
                height: 36
                hoverEnabled: true
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("%1 entries: %2").arg(pattern.count).arg(pattern.templateParts.join("*"))
                onClicked: root.openIndex = pattern.open ? -1 : pattern.index
                background: Rectangle {
                    color: pattern.open ? Theme.surface : (header.hovered ? Theme.surface : "transparent")
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.surface }
                }
                contentItem: RowLayout {
                    spacing: 12
                    Text {
                        Layout.preferredWidth: 56
                        Layout.leftMargin: 16
                        text: pattern.count.toLocaleString(Qt.locale(), "f", 0)
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: Theme.textStrong
                    }
                    Rectangle {
                        Layout.preferredWidth: 72
                        implicitHeight: 6
                        radius: 3
                        color: Theme.subtle
                        Rectangle {
                            width: parent.width * pattern.share
                            height: parent.height
                            radius: 3
                            color: Theme.levelColor(pattern.level)
                        }
                    }
                    Text {
                        Layout.preferredWidth: 56
                        text: pattern.level
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: Theme.levelTextColor(pattern.level)
                    }
                    // Literal parts and "*" variables alternate (variables at odd indexes).
                    Row {
                        Layout.fillWidth: true
                        clip: true
                        Repeater {
                            model: pattern.templateParts.length * 2 - 1
                            delegate: Text {
                                id: part
                                required property int index
                                readonly property bool variable: part.index % 2 === 1
                                text: part.variable ? "*" : pattern.templateParts[part.index / 2]
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontSm
                                color: part.variable ? Theme.variable : Theme.text
                            }
                        }
                    }
                    Sparkline {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 16
                        values: pattern.trend
                        maxValue: pattern.trendMax
                        color: Theme.levelColor(pattern.level)
                    }
                    Text {
                        Layout.preferredWidth: 72
                        Layout.rightMargin: 16
                        text: pattern.lastSeen
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }
                }
            }

            // Variable values and actions
            Rectangle {
                visible: pattern.open
                width: parent.width
                height: visible ? details.implicitHeight + 24 : 0
                color: Theme.surface
                ColumnLayout {
                    id: details
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.margins: 12
                    anchors.leftMargin: 16 + 56 + 12
                    spacing: 6
                    SectionLabel { visible: pattern.examples.length > 0; text: qsTr("Variable values") }
                    Repeater {
                        model: pattern.examples
                        delegate: Text {
                            id: example
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: qsTr("* #%1: %2").arg(example.index + 1).arg(example.modelData.join(" · "))
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontSm
                            color: Theme.text
                        }
                    }
                    Row {
                        spacing: 8
                        AppButton {
                            variant: "primary"
                            text: qsTr("Show %n entries", "", pattern.count)
                            onClicked: { Session.showPattern(pattern.index, false); Session.patternsEnabled = false }
                        }
                        AppButton {
                            text: qsTr("Exclude the pattern")
                            onClicked: { Session.showPattern(pattern.index, true); Session.patternsEnabled = false }
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
