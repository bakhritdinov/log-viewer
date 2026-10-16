import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The version and what the app keeps on this phone. (In the browser a new
// version arrives through the PWA shell; in a store app the store updates it.)
SettingsScreen {
    id: root

    signal notice(string text)

    title: qsTr("About")

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        AppLogo { size: 56 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "LogViewer " + Updates.currentVersion
                font.family: Theme.sans
                font.pixelSize: Theme.fontXl + 2
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }
            Text {
                text: Qt.platform.os === "wasm" ? qsTr("Web app (PWA)")
                    : Qt.platform.os === "android" ? "Android"
                    : Qt.platform.os === "ios" ? "iOS" : qsTr("Phone layout on the desktop")
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textMuted
            }
        }
    }

    SectionLabel { Layout.topMargin: 16; text: qsTr("Data on this phone") }
    SettingRow {
        title: qsTr("Saved queries")
        hint: qsTr("%n saved", "", Session.savedQueries.count)
        // To another phone or the desktop app, and back (a JSON file).
        GridLayout {
            Layout.fillWidth: true
            visible: Session.device.canExchangeFiles
            columns: 2
            columnSpacing: 8
            AppButton {
                Layout.fillWidth: true
                touch: true
                iconName: "download"
                text: qsTr("Export")
                enabled: Session.savedQueries.count > 0
                onClicked: Session.device.saveFile("logviewer-queries.json", Session.savedQueriesJson())
            }
            AppButton {
                Layout.fillWidth: true
                touch: true
                text: qsTr("Import from a file")
                onClicked: Session.device.openFile()
            }
        }
    }
    Connections {
        target: Session.device
        function onFileOpened(content) {
            const added = Session.importSavedQueriesJson(content, false)
            root.notice(added < 0 ? qsTr("The file is not a list of saved queries")
                                  : qsTr("%n query(-ies) added", "", added))
        }
    }
    SettingRow {
        title: qsTr("Search history")
        hint: qsTr("%n recent queries", "", Session.history.length)
        AppButton {
            Layout.fillWidth: true
            touch: true
            enabled: Session.history.length > 0
            text: qsTr("Clear the search history")
            onClicked: clearDialog.open()
        }
    }
    Text {
        Layout.fillWidth: true
        text: qsTr("Environments, saved queries and history stay on this phone; nothing is sent anywhere but your Grafana.")
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }

    ConfirmDialog {
        id: clearDialog
        title: qsTr("Clear the search history?")
        message: qsTr("Recent queries are removed. Saved queries stay.")
        confirmText: qsTr("Clear")
        onConfirmed: { Session.clearHistory(); root.notice(qsTr("Search history cleared")) }
    }
}
