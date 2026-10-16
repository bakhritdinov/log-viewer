import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Version, updates and the data stored on this device.
ColumnLayout {
    id: root

    // Notices go to the window's toast.
    function notify(text) {
        const w = root.ApplicationWindow.window
        if (w && w.notify) w.notify(text)   // qmllint disable missing-property
    }

    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 24
        Layout.topMargin: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            AppLogo { size: 52 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "LogViewer " + Updates.currentVersion
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
                Text {
                    text: qsTr("Desktop · %1").arg(Qt.platform.os)
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
        }

        // The update, in whatever state it is.
        Rectangle {
            id: update
            readonly property string state: Updates.state
            readonly property color tint: state === "available" || state === "downloading" ? Theme.accent
                                        : state === "ready" ? Theme.success
                                        : state === "failed" ? Theme.warn : Theme.border
            Layout.fillWidth: true
            implicitHeight: updateRow.implicitHeight + 24
            radius: Theme.radiusLg - 2
            color: tint === Theme.border ? "transparent" : Theme.tint(tint, 0.08)
            border.width: 1
            border.color: tint === Theme.border ? Theme.border : Theme.tint(tint, 0.45)

            RowLayout {
                id: updateRow
                anchors.fill: parent
                anchors.margins: 12
                anchors.leftMargin: 14
                spacing: 12
                // Icon, first text line and buttons share one centre line: everything is
                // top-aligned and the shorter items are pushed down to the buttons' middle.
                Icon {
                    id: updateIcon
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.round((Theme.controlHeight - size) / 2)
                    name: update.state === "checking" ? "refresh"
                        : update.state === "uptodate" ? "check"
                        : update.state === "ready" ? "refresh"
                        : update.state === "failed" ? "warning" : "download"
                    size: 18
                    color: update.state === "uptodate" || update.state === "ready" ? Theme.success
                         : update.state === "failed" ? Theme.warn : Theme.accent
                    RotationAnimator on rotation {
                        running: update.state === "checking"
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.round((Theme.controlHeight - updateTitle.firstLineHeight) / 2)
                    spacing: 4
                    Text {
                        id: updateTitle
                        readonly property real firstLineHeight: lineCount > 0 ? implicitHeight / lineCount : implicitHeight
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: {
                            switch (update.state) {
                            case "checking": return qsTr("Checking for updates…")
                            case "uptodate": return Updates.lastCheckText !== ""
                                                    ? qsTr("You have the latest version · checked %1").arg(Updates.lastCheckText)
                                                    : qsTr("You have the latest version")
                            case "available": return qsTr("Version %1 is available").arg(Updates.latestVersion)
                            case "downloading": return qsTr("Downloading %1 · %2 of %3 MB").arg(Updates.latestVersion)
                                                    .arg((Updates.downloadedBytes / 1048576).toFixed(0))
                                                    .arg((Updates.totalBytes / 1048576).toFixed(0))
                            case "ready": return qsTr("Version %1 installs on restart").arg(Updates.latestVersion)
                            case "failed": return qsTr("Could not check: %1").arg(Updates.errorMessage)
                            }
                            return qsTr("Updates come from GitHub Releases")
                        }
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.Medium
                        color: Theme.textStrong
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: update.state === "available" && Updates.releaseNotes !== ""
                        text: Updates.releaseNotes
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        visible: update.state === "downloading"
                        implicitHeight: 4
                        radius: 2
                        color: Theme.subtle
                        Rectangle {
                            width: parent.width * (Updates.totalBytes > 0 ? Updates.downloadedBytes / Updates.totalBytes : 0)
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }
                }
                AppButton {
                    Layout.alignment: Qt.AlignTop
                    visible: update.state === "idle" || update.state === "uptodate" || update.state === "failed"
                    text: update.state === "idle" ? qsTr("Check for updates") : update.state === "failed" ? qsTr("Retry") : qsTr("Check again")
                    onClicked: Updates.forceCheck()
                }
                AppButton {
                    Layout.alignment: Qt.AlignTop
                    visible: update.state === "available"
                    variant: "primary"
                    text: Updates.canInstallInPlace ? qsTr("Download and install") : qsTr("Open the release page")
                    onClicked: Updates.canInstallInPlace ? Updates.downloadUpdate() : Updates.openReleasePage()
                }
                AppButton {
                    Layout.alignment: Qt.AlignTop
                    visible: update.state === "downloading"
                    text: qsTr("Cancel")
                    onClicked: Updates.cancel()
                }
                AppButton {
                    Layout.alignment: Qt.AlignTop
                    visible: update.state === "ready"
                    variant: "primary"
                    text: qsTr("Restart")
                    onClicked: Updates.installAndRestart()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 44
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: qsTr("Check for updates at start-up")
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textStrong
            }
            AppSwitch {
                checked: Updates.autoCheck
                onToggled: Updates.autoCheck = checked
                Accessible.name: qsTr("Check for updates at start-up")
            }
        }

        SectionLabel { Layout.topMargin: 6; text: qsTr("Data on this device") }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: qsTr("Saved queries · %1").arg(Session.savedQueries.count)
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.text
            }
            AppButton {
                text: qsTr("Export…")
                enabled: Session.savedQueries.count > 0
                onClicked: exportDialog.open()
            }
            AppButton {
                text: qsTr("Import…")
                onClicked: importDialog.open()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: qsTr("Search history · %n search(es)", "", Session.history.length)
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.text
            }
            AppButton {
                variant: "danger"
                text: qsTr("Clear search history")
                enabled: Session.history.length > 0
                onClicked: confirmClear.open()
            }
        }
    }
    Item { Layout.fillHeight: true }

    FileDialog {
        id: exportDialog
        title: qsTr("Export saved queries")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [qsTr("JSON files (*.json)")]
        onAccepted: {
            const n = Session.exportSavedQueries(selectedFile)
            root.notify(n >= 0 ? qsTr("%n query(ies) exported", "", n) : qsTr("Could not write the file"))
        }
    }
    FileDialog {
        id: importDialog
        title: qsTr("Import saved queries")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("JSON files (*.json)")]
        onAccepted: importChoice.open()
    }
    ChoiceDialog {
        id: importChoice
        title: qsTr("Import saved queries")
        message: qsTr("Add the queries from the file to yours, or replace yours with them?")
        primaryText: qsTr("Add")
        secondaryText: qsTr("Replace")
        onPrimaryChosen: root.importFile(false)
        onSecondaryChosen: root.importFile(true)
    }
    function importFile(replace) {
        const n = Session.importSavedQueries(importDialog.selectedFile, replace)
        notify(n >= 0 ? qsTr("%n query(ies) added", "", n) : qsTr("This is not a file of saved queries"))
    }
    ConfirmDialog {
        id: confirmClear
        title: qsTr("Clear the search history?")
        message: qsTr("The %n recent search(es) are removed from this device. Saved queries stay.", "", Session.history.length)
        confirmText: qsTr("Clear history")
        onConfirmed: Session.clearHistory()
    }
}
