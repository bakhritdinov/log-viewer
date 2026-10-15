import QtQuick
import QtQuick.Layouts
import LogViewer.Ui

// First run: nothing is connected yet.
Item {
    id: root

    signal settingsRequested()

    EmptyState {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 360)
        touch: true
        iconName: "server"
        title: qsTr("Connect Grafana")
        message: qsTr("Add the address of your Grafana and the logs data source. The connection is checked before it is saved.")
        AppButton {
            touch: true
            variant: "primary"
            text: qsTr("Open settings")
            onClicked: root.settingsRequested()
        }
    }
}
