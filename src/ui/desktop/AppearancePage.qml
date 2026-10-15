pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Theme, table density and type, message display.
Flickable {
    id: root

    clip: true
    contentHeight: column.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { }

    ColumnLayout {
        id: column
        x: 24
        y: 20
        width: root.width - 48
        spacing: 4

        SectionLabel { text: qsTr("Theme") }
        RowLayout {
            Layout.topMargin: 8
            Layout.bottomMargin: 6
            spacing: 12
            Accessible.role: Accessible.Grouping
            Accessible.name: qsTr("Theme")
            ThemeCard { scheme: "dark"; title: qsTr("Dark") }
            ThemeCard { scheme: "light"; title: qsTr("Light") }
            ThemeCard { scheme: "system"; title: qsTr("As in the system") }
        }
        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            wrapMode: Text.Wrap
            text: qsTr("The theme changes at once. The moon/sun button in the top bar switches between dark and light.")
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }

        SectionLabel { text: qsTr("Table") }
        PrefRow {
            title: qsTr("Density")
            subtitle: qsTr("Row height: compact fits more rows on the screen")
            SegmentedControl {
                accessibleName: qsTr("Density")
                model: [{ label: qsTr("Compact"), value: "compact" }, { label: qsTr("Normal"), value: "normal" },
                        { label: qsTr("Comfortable"), value: "comfortable" }]
                value: Session.prefs.density
                onActivated: v => Session.prefs.density = v
            }
        }
        PrefRow {
            title: qsTr("Log text size")
            subtitle: qsTr("Rows and the message in the details; the interface keeps its size")
            SegmentedControl {
                accessibleName: qsTr("Log text size")
                model: [11, 12, 13, 14, 15].map(n => ({ label: String(n), value: n }))
                value: Session.prefs.logFontSize
                onActivated: v => Session.prefs.logFontSize = v
            }
        }
        PrefRow {
            title: qsTr("Long messages")
            subtitle: qsTr("Lines of a message shown in a row; the rest is cut with …")
            SegmentedControl {
                accessibleName: qsTr("Long messages")
                model: [{ label: qsTr("1 line"), value: 1 }, { label: qsTr("2 lines"), value: 2 }, { label: qsTr("3 lines"), value: 3 }]
                value: Session.prefs.messageLines
                onActivated: v => Session.prefs.messageLines = v
            }
        }
        PrefRow {
            title: qsTr("Tint ERROR and WARN rows")
            subtitle: qsTr("A light red or yellow background, not only the stripe on the left")
            AppSwitch {
                checked: Session.prefs.tintRows
                onToggled: Session.prefs.tintRows = checked
                Accessible.name: qsTr("Tint ERROR and WARN rows")
            }
        }

        SectionLabel { Layout.topMargin: 12; text: qsTr("Messages") }
        PrefRow {
            title: qsTr("Pretty JSON in details")
            subtitle: qsTr("A message that is JSON is indented and coloured")
            AppSwitch {
                checked: Session.prefs.prettyJson
                onToggled: Session.prefs.prettyJson = checked
                Accessible.name: qsTr("Pretty JSON in details")
            }
        }
    }

    // A small preview of a theme; the choice is a radio.
    component ThemeCard: AbstractButton {
        id: card
        property string scheme
        property string title
        readonly property bool selected: Session.prefs.theme === scheme
        readonly property bool dark: scheme !== "light"   // the left half of "system" is dark
        implicitWidth: 184
        implicitHeight: 140
        padding: 8
        Accessible.role: Accessible.RadioButton
        Accessible.name: title
        Accessible.checked: selected
        onClicked: Session.prefs.theme = card.scheme
        background: Rectangle {
            radius: Theme.radiusLg
            color: card.selected ? Theme.successSoft : (card.hovered ? Theme.surface : "transparent")
            border.width: card.visualFocus ? 2 : 1
            border.color: card.visualFocus ? Theme.focusRing : card.selected ? Theme.successBorder : Theme.border
        }
        contentItem: ColumnLayout {
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: card.scheme === "light" ? "#ffffff" : "#0d1117"
                border.width: 1
                border.color: card.scheme === "light" ? "#d0d7de" : "#30363d"
                clip: true
                Rectangle { width: parent.width; height: 16; color: card.dark ? "#161b22" : "#f6f8fa" }
                // "As in the system": the right half in the light theme.
                Rectangle {
                    visible: card.scheme === "system"
                    x: parent.width / 2; width: parent.width / 2; height: parent.height
                    color: "#ffffff"
                    Rectangle { width: parent.width; height: 16; color: "#f6f8fa" }
                }
                Rectangle { x: 0; y: 16; width: parent.width * 0.3; height: parent.height - 16; color: "transparent"; border.width: 0
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: card.dark ? "#21262d" : "#eaeef2" } }
                Column {
                    x: parent.width * 0.3 + 8
                    y: 24
                    spacing: 5
                    Repeater {
                        model: [0.8, 0.6, 0.7, 0.5]
                        delegate: Rectangle {
                            id: line
                            required property real modelData
                            required property int index
                            width: 110 * line.modelData
                            height: 5
                            radius: 2
                            color: line.index === 2 ? (card.dark ? Qt.rgba(0.22, 0.545, 0.992, 0.4) : Qt.rgba(0.035, 0.412, 0.855, 0.3))
                                               : (card.dark ? "#30363d" : "#d0d7de")
                        }
                    }
                }
            }
            Row {
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; radius: 8
                    color: "transparent"
                    border.width: card.selected ? 5 : 1
                    border.color: card.selected ? Theme.success : Theme.textMuted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.title
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }
        }
    }
}
