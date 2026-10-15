pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// The three sections. The active one has a pill behind its icon and a bold
// label; "!" on Settings flags a connection problem.
Rectangle {
    id: root

    property int current: 0
    property bool settingsAlert: false

    signal picked(int index)

    implicitHeight: 64
    color: Theme.surface
    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("Sections")

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }

    RowLayout {
        anchors.fill: parent
        anchors.bottomMargin: 6
        spacing: 0
        Repeater {
            model: [
                { label: qsTr("Logs"), icon: "logs" },
                { label: qsTr("Chart"), icon: "chart" },
                { label: qsTr("Settings"), icon: "settings" },
            ]
            delegate: AbstractButton {
                id: tab
                required property var modelData
                required property int index
                readonly property bool active: root.current === index
                Layout.fillWidth: true
                Layout.fillHeight: true
                focusPolicy: Qt.NoFocus
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.label
                Accessible.selected: active
                onClicked: root.picked(index)
                // Pressed: darker for the duration of the touch (no hover on phones).
                background: Rectangle { color: tab.pressed ? Theme.tint(Theme.textStrong, 0.06) : "transparent" }
                contentItem: ColumnLayout {
                    spacing: 3
                    Item { Layout.fillHeight: true }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 56
                        implicitHeight: 28
                        radius: 14
                        color: tab.active ? Theme.accentSoft : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            name: tab.modelData.icon
                            size: 22
                            color: tab.active ? Theme.textStrong : Theme.textMuted
                        }
                        Rectangle {
                            visible: tab.index === 2 && root.settingsAlert
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: -2
                            width: 16; height: 16; radius: 8
                            color: Theme.danger
                            border.width: 2
                            border.color: Theme.surface
                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                font.family: Theme.sans
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: tab.modelData.label
                        font.family: Theme.sans
                        font.pixelSize: root.width < 340 ? 10 : 11
                        font.weight: tab.active ? Font.DemiBold : Font.Medium
                        color: tab.active ? Theme.textStrong : Theme.textMuted
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
