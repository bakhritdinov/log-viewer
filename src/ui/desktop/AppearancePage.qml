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
        Option {
            title: qsTr("Dark theme")
            checked: root.darkTheme
            onToggled: on => root.darkThemeToggled(on)
        }
        Option {
            title: qsTr("Pretty JSON in details")
            subtitle: qsTr("Format messages that are JSON")
            checked: root.prettyJson
            onToggled: on => root.prettyJsonToggled(on)
        }
    }
    Item { Layout.fillHeight: true }

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
        Switch {
            checked: option.checked
            onToggled: option.toggled(checked)
            Accessible.name: option.title
        }
    }
}
