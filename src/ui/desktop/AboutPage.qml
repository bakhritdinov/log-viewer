import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Version and local data.
ColumnLayout {
    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 24
        Layout.topMargin: 20
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: qsTr("Version"); font.family: Theme.sans; font.pixelSize: Theme.fontMd; color: Theme.text }
            Text { text: Qt.application.version; font.family: Theme.mono; font.pixelSize: Theme.fontMd; color: Theme.textMuted }
        }
        AppButton {
            variant: "danger"
            text: qsTr("Clear search history")
            enabled: Session.history.length > 0
            onClicked: Session.clearHistory()
        }
    }
    Item { Layout.fillHeight: true }
}
