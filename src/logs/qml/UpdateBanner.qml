import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: root

    // Hide entirely in states that have nothing to show.
    // Also respects the user's dismiss action via configManager.
    readonly property bool _hasUpdate: typeof updateChecker !== "undefined" && updateChecker !== null
                                       && (updateChecker.state === "available"
                                        || updateChecker.state === "downloading"
                                        || updateChecker.state === "ready"
                                        || updateChecker.state === "failed")
    readonly property bool _dismissed: typeof configManager !== "undefined" && configManager !== null
                                       && updateChecker.state === "available"
                                       && updateChecker.latestVersion === configManager.dismissedUpdateVersion()

    visible: _hasUpdate && !_dismissed
    implicitHeight: visible ? 40 : 0
    color: updateChecker && updateChecker.state === "failed" ? Theme.bgRaised : Theme.bgRaised
    border.color: updateChecker && updateChecker.state === "failed" ? Theme.danger : Theme.accent
    border.width: 1

    function _fmtMB(bytes) {
        if (!bytes || bytes <= 0) return "0 МБ"
        return (bytes / (1024 * 1024)).toFixed(1) + " МБ"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp3
        anchors.rightMargin: Theme.sp2
        spacing: Theme.sp2

        // Status icon + text — switches by state.
        Text {
            text: {
                if (!updateChecker) return ""
                switch (updateChecker.state) {
                    case "available":   return "⬆"
                    case "downloading": return "↓"
                    case "ready":       return "✓"
                    case "failed":      return "⚠"
                }
                return ""
            }
            color: updateChecker && updateChecker.state === "failed" ? Theme.danger : Theme.accent
            font.pixelSize: Theme.fsLg
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            color: Theme.text
            font.pixelSize: Theme.fsMd
            elide: Text.ElideRight
            text: {
                if (!updateChecker) return ""
                switch (updateChecker.state) {
                    case "available":
                        return "Доступна новая версия " + updateChecker.latestVersion
                             + " (у вас " + updateChecker.currentVersion + ")"
                    case "downloading": {
                        let pct = updateChecker.totalBytes > 0
                                ? Math.round(updateChecker.downloadedBytes / updateChecker.totalBytes * 100)
                                : 0
                        return "Скачивание " + updateChecker.latestVersion + "… "
                             + pct + "%  ·  "
                             + root._fmtMB(updateChecker.downloadedBytes)
                             + " из " + root._fmtMB(updateChecker.totalBytes)
                    }
                    case "ready":
                        return "Версия " + updateChecker.latestVersion
                             + " готова к установке. Приложение перезапустится."
                    case "failed":
                        return "Не удалось обновиться: " + updateChecker.errorMessage
                }
                return ""
            }
        }

        // Inline progress bar — only while downloading.
        ProgressBar {
            visible: updateChecker && updateChecker.state === "downloading"
            Layout.preferredWidth: 140
            Layout.alignment: Qt.AlignVCenter
            from: 0
            to: updateChecker && updateChecker.totalBytes > 0 ? updateChecker.totalBytes : 1
            value: updateChecker ? updateChecker.downloadedBytes : 0

            background: Rectangle {
                implicitHeight: 6
                color: Theme.bgSubtle
                radius: 3
            }
            contentItem: Item {
                implicitHeight: 6
                Rectangle {
                    width: parent.width * (updateChecker && updateChecker.totalBytes > 0
                                          ? updateChecker.downloadedBytes / updateChecker.totalBytes
                                          : 0)
                    height: parent.height
                    color: Theme.accent
                    radius: 3
                }
            }
        }

        // --- Action buttons. Layout depends on state. ---

        SecondaryButton {
            visible: updateChecker && updateChecker.state === "available"
            text: "Что нового"
            Layout.alignment: Qt.AlignVCenter
            onClicked: updateChecker.openReleasePage()
        }

        PrimaryButton {
            visible: updateChecker && updateChecker.state === "available"
            text: updateChecker && updateChecker.canInstallInPlace ? "Скачать" : "Открыть страницу"
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                if (updateChecker.canInstallInPlace) updateChecker.downloadUpdate()
                else                                  updateChecker.openReleasePage()
            }
        }

        SecondaryButton {
            visible: updateChecker && updateChecker.state === "downloading"
            text: "Отмена"
            Layout.alignment: Qt.AlignVCenter
            onClicked: updateChecker.cancel()
        }

        PrimaryButton {
            visible: updateChecker && updateChecker.state === "ready"
            text: "Установить и перезапустить"
            Layout.alignment: Qt.AlignVCenter
            onClicked: updateChecker.installAndRestart()
        }

        SecondaryButton {
            visible: updateChecker && updateChecker.state === "failed"
            text: "Повторить"
            Layout.alignment: Qt.AlignVCenter
            // Manual retry bypasses the 4h throttle.
            onClicked: updateChecker.forceCheck()
        }

        // Dismiss "×" — only meaningful while we're nagging the user about an
        // available update; once they've started downloading or it's failed,
        // hiding behind × doesn't make sense.
        Button {
            visible: updateChecker && updateChecker.state === "available"
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 28
            implicitHeight: 28
            flat: true
            background: Rectangle {
                color: parent.hovered ? Theme.bgHover : "transparent"
                radius: Theme.rSm
            }
            contentItem: Text {
                text: "×"
                color: Theme.textMuted
                font.pixelSize: Theme.fsXl
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (configManager && updateChecker)
                    configManager.setDismissedUpdateVersion(updateChecker.latestVersion)
            }
            ToolTip.visible: hovered
            ToolTip.text: "Скрыть до следующей версии"
        }
    }
}
