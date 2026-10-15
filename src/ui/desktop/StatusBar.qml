pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Connection state, last query time, key hints and the version.
Rectangle {
    id: root

    property var hints: []              // [{ keys: ["F5"], text: "refresh" }]

    readonly property bool connected: !Session.hasError && !Session.needsSetup && Session.namespaces.length > 0

    implicitHeight: 26
    color: Theme.surface

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        Row {
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 4
                color: root.connected ? Theme.success : Session.discovering ? Theme.warn : Theme.textMuted
            }
            StatusText {
                text: Session.discovering ? qsTr("Connecting · %1").arg(Session.environmentName)
                    : root.connected ? qsTr("Connected · %1").arg(Session.environmentName)
                    : qsTr("Not connected")
                color: root.connected ? Theme.success : Theme.textMuted
            }
        }
        StatusText {
            visible: Session.lastQueryMs > 0
            text: qsTr("Query %1 ms").arg(Session.lastQueryMs.toLocaleString(Qt.locale(), "f", 0))
        }
        Item { Layout.fillWidth: true }
        Row {
            spacing: 10
            Repeater {
                model: root.hints
                delegate: Row {
                    id: hint
                    required property var modelData
                    spacing: 4
                    Repeater {
                        model: hint.modelData.keys
                        delegate: Kbd {
                            required property string modelData
                            text: modelData
                        }
                    }
                    StatusText { text: hint.modelData.text }
                }
            }
        }
        StatusText { text: "v" + Qt.application.version; font.family: Theme.mono }
    }

    component StatusText: Text {
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }
}
