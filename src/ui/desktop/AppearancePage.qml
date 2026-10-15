pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// Theme and message formatting.
ColumnLayout {
    id: root

    property bool darkTheme: true
    property bool prettyJson: true

    signal darkThemeToggled(bool on)
    signal prettyJsonToggled(bool on)

    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 24
        Layout.topMargin: 20
        spacing: 4
        SectionLabel { text: qsTr("Theme") }
        RowLayout {
            Layout.topMargin: 8
            Layout.bottomMargin: 6
            spacing: 12
            Accessible.role: Accessible.Grouping
            Accessible.name: qsTr("Theme")
            ThemeCard { dark: true; title: qsTr("Dark"); selected: root.darkTheme; onPicked: root.darkThemeToggled(true) }
            ThemeCard { dark: false; title: qsTr("Light"); selected: !root.darkTheme; onPicked: root.darkThemeToggled(false) }
        }
        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            wrapMode: Text.Wrap
            text: qsTr("The theme changes at once. The moon/sun button in the top bar switches the same.")
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
        SectionLabel { text: qsTr("Messages") }
        Option {
            title: qsTr("Pretty JSON in details")
            subtitle: qsTr("Format messages that are JSON")
            checked: root.prettyJson
            onToggled: on => root.prettyJsonToggled(on)
        }
    }
    Item { Layout.fillHeight: true }

    // A small preview of a theme; the choice is a radio.
    component ThemeCard: AbstractButton {
        id: card
        property bool dark
        property string title
        property bool selected
        signal picked()
        implicitWidth: 244
        implicitHeight: 160
        padding: 8
        Accessible.role: Accessible.RadioButton
        Accessible.name: title
        Accessible.checked: selected
        onClicked: card.picked()
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
                color: card.dark ? "#0d1117" : "#ffffff"
                border.width: 1
                border.color: card.dark ? "#30363d" : "#d0d7de"
                clip: true
                Rectangle { width: parent.width; height: 16; color: card.dark ? "#161b22" : "#f6f8fa" }
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
                            width: 140 * line.modelData
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

    component Option: RowLayout {
        id: option
        property string title
        property string subtitle
        property bool checked
        signal toggled(bool on)
        Layout.fillWidth: true
        Layout.minimumHeight: 52
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { Layout.fillWidth: true; text: option.title; font.family: Theme.sans; font.pixelSize: Theme.fontMd; color: Theme.textStrong }
            Text {
                visible: option.subtitle !== ""
                text: option.subtitle
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
        AppSwitch {
            checked: option.checked
            onToggled: option.toggled(checked)
            Accessible.name: option.title
        }
    }
}
