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
    property var shortcuts: []

    // Pages by name, so a new page does not shift callers' numbers.
    readonly property var pageNames: ["connections", "language", "appearance", "table", "behaviour", "shortcuts", "about"]
    function openSection(index) {
        section = typeof index === "string" ? Math.max(0, pageNames.indexOf(index)) : index
        open()
    }
    // Connections with the label fields open (labels were not recognised).
    function openLabels() {
        openSection(0)
        Qt.callLater(() => connections.showLabels())
    }
    // Connections with a new environment, its name filled in (from a share link).
    function openNewEnvironment(name) {
        openSection(0)
        Qt.callLater(() => connections.createNamed(name))
    }

    // Leaving the connections page asks about unsaved changes first.
    function leaveThen(then) {
        if (section === 0) connections.confirmLeave(then)
        else then()
    }
    function requestClose() { leaveThen(() => root.close()) }

    readonly property var sections: [qsTr("Connections"), qsTr("Language"), qsTr("Appearance"), qsTr("Table"), qsTr("Behaviour"), qsTr("Keyboard shortcuts"), qsTr("Version")]

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(900, parent.width - 48)
    height: Math.min(800, parent.height - 48)
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose           // Esc goes through requestClose()

    Overlay.modal: Rectangle { color: Theme.overlay }
    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: RowLayout {
        spacing: 0
        focus: true
        Keys.onEscapePressed: root.requestClose()
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Settings")

        // Navigation
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            // Inside the dialog's border, rounded only where the dialog is.
            Layout.leftMargin: 1
            Layout.topMargin: 1
            Layout.bottomMargin: 1
            color: Theme.bg
            topLeftRadius: Theme.radiusLg + 1
            bottomLeftRadius: Theme.radiusLg + 1
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
                        // Basic's 12 px vertical padding pushes the content below the row's centre.
                        topPadding: 0
                        bottomPadding: 0
                        hoverEnabled: true
                        required property int index
                        required property string modelData
                        readonly property bool current: root.section === nav.index
                        Layout.fillWidth: true
                        implicitHeight: 34
                        Accessible.name: nav.modelData
                        Accessible.selected: nav.current
                        onClicked: if (!nav.current) root.leaveThen(() => root.section = nav.index)
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
                IconButton { iconName: "close"; label: qsTr("Close"); shortcut: "Esc"; onClicked: root.requestClose() }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.section
                ConnectionsPage { id: connections; onDone: root.close() }
                LanguagePage { onDone: root.close() }
                AppearancePage { }
                TablePage { }
                BehaviourPage { }
                ShortcutsPage { shortcuts: root.shortcuts }
                AboutPage { }
            }
        }
    }
}
