pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Context on the left (environment, source, period), global actions on the right.
// In live mode the period and refresh give way to the live controls.
Rectangle {
    id: root

    signal settingsRequested()
    signal themeToggled()

    function openSourcePicker() { sourcePicker.open() }
    function openTimePicker() { timePopup.open() }
    function openShare() { sharePopup.open() }

    readonly property bool live: Session.live.running
    readonly property var refreshOptions: [
        { seconds: 0, label: qsTr("Off") },
        { seconds: 5, label: qsTr("5 s") },
        { seconds: 10, label: qsTr("10 s") },
        { seconds: 30, label: qsTr("30 s") },
        { seconds: 60, label: qsTr("1 min") },
    ]

    implicitHeight: 52
    color: Theme.surface

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        Row {
            Layout.rightMargin: 6
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "logs"; size: 20; color: Theme.accent }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "LogViewer"
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }
        }

        // Environment
        Button {
            id: envButton
            implicitHeight: Theme.controlHeight
            leftPadding: 10
            rightPadding: 10
            visible: Session.environments.count > 0
            Accessible.name: qsTr("Environment: %1").arg(Session.environmentName)
            onClicked: envMenu.open()
            contentItem: Row {
                spacing: 8
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Session.environmentColor }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Session.environmentName
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronDown"; size: 12; color: Theme.textMuted }
            }
            background: Rectangle {
                radius: Theme.radiusMd
                color: Theme.tint(Session.environmentColor, envButton.hovered ? 0.22 : 0.14)
                border.width: 1
                border.color: envButton.visualFocus ? Theme.focusRing : Theme.tint(Session.environmentColor, 0.6)
            }

            AppMenu {
                id: envMenu
                y: envButton.height + 4
                Repeater {
                    model: Session.environments
                    delegate: AppMenuItem {
                        required property string id
                        required property string name
                        required property string color
                        required property bool current
                        text: name
                        dotColor: color
                        checkedMark: current
                        onTriggered: Session.switchEnvironment(id)
                    }
                }
                AppMenuSeparator { }
                AppMenuItem { text: qsTr("Manage environments…"); onTriggered: root.settingsRequested() }
            }
        }

        // Source
        AppButton {
            id: sourceButton
            Layout.minimumWidth: 260
            Accessible.name: qsTr("Source: %1 / %2").arg(Session.namespaceName).arg(Session.app)
            onClicked: sourcePicker.open()
            contentItem: RowLayout {
                spacing: 8
                Icon { name: "source"; size: 14; color: Theme.textMuted }
                Row {
                    Layout.fillWidth: true
                    spacing: 6
                    clip: true
                    Text {
                        text: Session.namespaceName === "" ? qsTr("Choose a source") : Session.namespaceName
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontMd
                        color: Session.namespaceName === "" ? Theme.text : Theme.textMuted
                    }
                    Text {
                        visible: Session.namespaceName !== ""
                        text: "/"
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontMd
                        color: Theme.border
                    }
                    Text {
                        visible: Session.namespaceName !== ""
                        text: Session.app
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontMd
                        color: Theme.textStrong
                    }
                }
                Icon { name: "chevronDown"; size: 12; color: Theme.textMuted }
            }

            SourcePicker {
                id: sourcePicker
                y: sourceButton.height + 4
            }
        }

        // Period
        AppButton {
            id: timeButton
            visible: !root.live
            iconName: "clock"
            text: Session.timeRangeLabel
            onClicked: timePopup.open()

            TimeRangePopup {
                id: timePopup
                y: timeButton.height + 4
            }
        }
        Text {
            visible: root.live
            text: qsTr("No period needed — new entries are shown")
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }

        Item { Layout.fillWidth: true }

        // Refresh + auto-refresh (split button)
        Row {
            visible: !root.live
            AppButton {
                id: refreshButton
                variant: "primary"
                iconName: "refresh"
                text: qsTr("Refresh")
                enabled: !Session.needsSetup
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Refresh (F5)")
                ToolTip.delay: 500
                onClicked: Session.search()
            }
            AppButton {
                id: autoButton
                variant: "primary"
                leftPadding: 8
                rightPadding: 8
                enabled: !Session.needsSetup
                Accessible.name: Session.autoRefreshSeconds > 0
                                 ? qsTr("Auto refresh: every %1").arg(autoButton.currentLabel)
                                 : qsTr("Auto refresh: off")
                readonly property string currentLabel: {
                    for (const o of root.refreshOptions)
                        if (o.seconds === Session.autoRefreshSeconds) return o.label
                    return qsTr("%1 s").arg(Session.autoRefreshSeconds)
                }
                onClicked: refreshMenu.open()
                contentItem: Row {
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Session.autoRefreshSeconds > 0
                        width: 6; height: 6; radius: 3
                        color: Theme.successText
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Session.autoRefreshSeconds > 0
                        text: autoButton.currentLabel
                        font: autoButton.font
                        color: Theme.textOnAccent
                    }
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronDown"; size: 12; color: Theme.textOnAccent }
                }

                AppMenu {
                    id: refreshMenu
                    y: autoButton.height + 4
                    x: autoButton.width - width
                    Repeater {
                        model: root.refreshOptions
                        delegate: AppMenuItem {
                            required property var modelData
                            text: modelData.seconds === 0 ? qsTr("Auto refresh off") : qsTr("Every %1").arg(modelData.label)
                            checkedMark: Session.autoRefreshSeconds === modelData.seconds
                            onTriggered: Session.autoRefreshSeconds = modelData.seconds
                        }
                    }
                    AppMenuSeparator { }
                    AppMenuItem {
                        text: qsTr("Live tail")
                        hint: "LIVE"
                        onTriggered: Session.live.start()
                    }
                }
            }
        }

        // Live controls
        Row {
            visible: root.live
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: liveLabel.implicitWidth + 24
                implicitHeight: 26
                radius: 13
                color: Session.live.paused ? Theme.subtle : Theme.successSoft
                border.width: 1
                border.color: Session.live.paused ? Theme.border : Theme.successBorder
                Row {
                    id: liveLabel
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: Session.live.paused ? Theme.textMuted : Theme.success
                        SequentialAnimation on opacity {
                            running: root.live && !Session.live.paused
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { from: 1; to: 0.3; duration: 700 }
                            NumberAnimation { from: 0.3; to: 1; duration: 700 }
                        }
                    }
                    Text {
                        text: qsTr("LIVE · ~%1 lines/s").arg(Session.live.ratePerSecond.toLocaleString(Qt.locale(), "f", 0))
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.DemiBold
                        color: Session.live.paused ? Theme.textMuted : Theme.successText
                    }
                }
            }
            AppButton {
                iconName: Session.live.paused ? "play" : "pause"
                text: Session.live.paused ? qsTr("Resume") : qsTr("Pause")
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Pause / resume (Space)")
                ToolTip.delay: 500
                onClicked: Session.live.paused = !Session.live.paused
            }
            IconButton {
                iconName: "close"
                label: qsTr("Leave live")
                onClicked: Session.live.stop()
            }
        }

        AppButton {
            id: shareButton
            visible: !root.live
            iconName: "link"
            text: qsTr("Share", "button: share a link")
            enabled: Session.namespaceName !== ""
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Link to the current selection")
            ToolTip.delay: 500
            onClicked: sharePopup.open()

            SharePopup {
                id: sharePopup
                y: shareButton.height + 4
                x: shareButton.width - width
            }
        }
        IconButton {
            iconName: Theme.dark ? "moon" : "sun"
            label: qsTr("Switch theme")
            onClicked: root.themeToggled()
        }
        IconButton {
            iconName: "settings"
            label: qsTr("Settings")
            onClicked: root.settingsRequested()
        }
    }
}
