import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Where am I: environment, namespace and app (tap to change) and refresh.
Rectangle {
    id: root

    signal environmentRequested()
    signal sourceRequested()

    implicitHeight: 60
    color: Theme.surface

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 6

        AbstractButton {
            id: envButton
            visible: !Session.needsSetup
            implicitHeight: 44
            implicitWidth: envBadge.implicitWidth + 8
            Accessible.name: qsTr("Environment: %1").arg(Session.environmentName)
            onClicked: root.environmentRequested()
            contentItem: Item {
                Rectangle {
                    id: envBadge
                    anchors.centerIn: parent
                    implicitWidth: envRow.implicitWidth + 16
                    implicitHeight: 26
                    radius: Theme.radiusMd
                    color: Theme.tint(Session.environmentColor, envButton.pressed ? 0.24 : 0.14)
                    border.width: 1
                    border.color: Theme.tint(Session.environmentColor, 0.6)
                    Row {
                        id: envRow
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Session.environmentColor }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Session.environmentName
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.DemiBold
                            color: Theme.textStrong
                        }
                    }
                }
            }
            background: null
        }

        AbstractButton {
            id: sourceButton
            Layout.fillWidth: true
            implicitHeight: 44
            enabled: !Session.needsSetup
            Accessible.name: qsTr("Source: %1 / %2").arg(Session.namespaceName).arg(Session.app)
            onClicked: root.sourceRequested()
            background: Rectangle { radius: Theme.radiusMd; color: sourceButton.pressed ? Theme.subtle : "transparent" }
            contentItem: ColumnLayout {
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    leftPadding: 6
                    visible: text !== ""
                    text: Session.needsSetup ? "" : Session.namespaceName
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    color: Theme.textMuted
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        Layout.maximumWidth: sourceButton.width - 30
                        leftPadding: 6
                        text: Session.needsSetup ? "LogViewer" : (Session.app !== "" ? Session.app : qsTr("Choose a source"))
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXl
                        font.weight: Font.DemiBold
                        color: Theme.textStrong
                    }
                    Icon { visible: !Session.needsSetup; name: "chevronDown"; size: 14; color: Theme.textMuted }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        // Refresh; the green dot means auto refresh is on. While loading it is
        // "Stop" (a square).
        IconButton {
            id: refresh
            visible: !Session.needsSetup
            touch: true
            iconName: Session.loading ? "stop" : "refresh"
            label: Session.loading ? qsTr("Stop")
                 : Session.autoRefreshSeconds > 0 ? qsTr("Refresh · auto refresh every %1 s").arg(Session.autoRefreshSeconds) : qsTr("Refresh")
            onClicked: Session.loading ? Session.stopLoading() : Session.search()
            Rectangle {
                visible: Session.autoRefreshSeconds > 0 && !Session.loading
                x: parent.width - 16; y: 9
                width: 8; height: 8; radius: 4
                color: Theme.success
                border.width: 2
                border.color: Theme.surface
            }
        }
    }
}
