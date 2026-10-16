pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Refresh (Stop while loading) and the auto-refresh menu with live tail, at
// the end of the search field where the search is run.
Row {
    id: root

    property string refreshKey
    readonly property bool noSource: Session.namespaceName === ""
    readonly property bool loading: Session.loading

    readonly property var refreshOptions: [
        { seconds: 0, label: qsTr("Off") },
        { seconds: 5, label: qsTr("5 s") },
        { seconds: 10, label: qsTr("10 s") },
        { seconds: 30, label: qsTr("30 s") },
        { seconds: 60, label: qsTr("1 min") },
    ]

    spacing: 6

    AppButton {
        id: refreshButton
        visible: !root.loading
        variant: "primary"
        iconName: "refresh"
        text: qsTr("Refresh")
        enabled: !Session.needsSetup && !root.noSource
        tooltip: qsTr("Refresh")
        shortcut: root.refreshKey
        onClicked: Session.search()
    }
    AppButton {
        id: stopButton
        visible: root.loading
        Accessible.name: qsTr("Stop loading")
        onClicked: Session.stopLoading()
        contentItem: Row {
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "refresh"
                size: 14
                color: Theme.accent
                RotationAnimator on rotation {
                    running: stopButton.visible
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Stop")
                font: stopButton.font
                color: Theme.textStrong
            }
            Kbd { anchors.verticalCenter: parent.verticalCenter; text: "Esc" }
        }
    }
    AppButton {
        id: autoButton
        variant: root.loading ? "secondary" : "primary"
        leftPadding: 8
        rightPadding: 8
        enabled: !Session.needsSetup && !root.noSource
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
                color: autoButton._fg
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chevronDown"; size: 12
                color: autoButton._fg
                rotation: refreshMenu.opened ? 180 : 0
            }
        }

        AppMenu {
            id: refreshMenu
            y: autoButton.height + 4
            x: autoButton.width - width
            Repeater {
                model: root.refreshOptions
                delegate: AppMenuItem {
                    required property var modelData
                    text: modelData.seconds === 0 ? qsTr("Auto refresh off")
                        : modelData.seconds === 60 ? qsTr("Every minute")
                        : qsTr("Every %1").arg(modelData.label)
                    // A fixed period does not change: nothing to refresh.
                    enabled: modelData.seconds === 0 || !Session.timeRangeAbsolute
                    checkedMark: Session.autoRefreshSeconds === modelData.seconds
                    onTriggered: Session.autoRefreshSeconds = modelData.seconds
                }
            }
            Text {
                visible: Session.timeRangeAbsolute
                Layout.maximumWidth: 240
                Layout.leftMargin: 32
                Layout.rightMargin: 12
                wrapMode: Text.Wrap
                text: qsTr("A fixed period needs no auto refresh")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            AppMenuSeparator { }
            AppMenuItem {
                text: qsTr("Live tail")
                dotColor: Theme.danger
                hint: "LIVE"
                hintDanger: true
                onTriggered: Session.live.start()
            }
        }
    }
}
