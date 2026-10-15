pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// Settings: connections, language, appearance, keys, version. Modal over the
// app; Esc closes.
Popup {
    id: root

    property int section: 0
    property bool prettyJson: true
    property bool darkTheme: true
    property var shortcuts: []

    function openSection(index) {
        section = index
        open()
    }

    readonly property var sections: [qsTr("Connections"), qsTr("Language"), qsTr("Appearance"), qsTr("Keyboard shortcuts"), qsTr("Version")]

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(900, parent.width - 48)
    height: Math.min(800, parent.height - 48)
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle { color: Theme.overlay }
    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: RowLayout {
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Settings")

        // Navigation
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: Theme.bg
            radius: Theme.radiusLg + 2
            Rectangle { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; width: 1; color: Theme.border }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                anchors.topMargin: 16
                spacing: 2
                Text {
                    Layout.leftMargin: 10
                    Layout.bottomMargin: 12
                    text: qsTr("Settings")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                    Accessible.role: Accessible.Heading
                }
                Repeater {
                    model: root.sections
                    delegate: ItemDelegate {
                        id: nav
                        required property int index
                        required property string modelData
                        readonly property bool current: root.section === nav.index
                        Layout.fillWidth: true
                        implicitHeight: 34
                        Accessible.name: nav.modelData
                        Accessible.selected: nav.current
                        onClicked: root.section = nav.index
                        background: Rectangle {
                            radius: Theme.radiusMd
                            color: nav.current ? Theme.accentSoft : (nav.hovered ? Theme.subtle : "transparent")
                        }
                        contentItem: Text {
                            text: nav.modelData
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                            color: nav.current ? Theme.textStrong : Theme.text
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // Page
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.leftMargin: 24
                spacing: 12
                Text {
                    text: root.section === 1 ? qsTr("Interface language") : root.section === 0 ? qsTr("Grafana connections") : root.sections[root.section]
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontLg + 1
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                    Accessible.role: Accessible.Heading
                }
                // Readable whatever language is on.
                Text {
                    visible: root.section === 1
                    text: "Til · Language"
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    color: Theme.textMuted
                }
                Item { Layout.fillWidth: true }
                IconButton { iconName: "close"; label: qsTr("Close (Esc)"); onClicked: root.close() }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.section
                ConnectionsPage { onDone: root.close() }
                LanguagePage { onDone: root.close() }
                AppearancePage {
                    darkTheme: root.darkTheme
                    prettyJson: root.prettyJson
                    onDarkThemeToggled: on => root.darkTheme = on
                    onPrettyJsonToggled: on => root.prettyJson = on
                }
                ShortcutsPage { shortcuts: root.shortcuts }
                AboutPage { }
            }
        }
    }
}
