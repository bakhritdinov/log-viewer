import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App

// Non-modal error: what happened, why, one main action; raw details on demand.
Rectangle {
    id: root

    property var error                  // ErrorInfo value type
    property bool touch: false
    property bool detailsOpen: false

    signal actionTriggered(int action)

    readonly property bool active: error !== undefined && error.active
    readonly property string iconName: {
        if (!active) return ""
        switch (error.kind) {
        case ErrorInfo.Unreachable: return "offline"
        case ErrorInfo.BlockedByBrowser: return "shield"
        case ErrorInfo.Unauthorized:
        case ErrorInfo.Forbidden: return "lock"
        case ErrorInfo.TooHeavy: return "clock"
        case ErrorInfo.Server: return "server"
        case ErrorInfo.NotFound:
        case ErrorInfo.UnknownLabels: return "search"
        }
        return "warning"
    }
    readonly property bool severe: active && error.kind !== ErrorInfo.TooHeavy && error.kind !== ErrorInfo.RateLimited
                                   && error.kind !== ErrorInfo.BlockedByBrowser

    visible: active
    implicitHeight: content.implicitHeight + 2 * (touch ? 14 : 12)
    radius: touch ? Theme.radiusLg : 0
    color: severe ? Theme.dangerSoft : Theme.warnSoft
    border.width: 1
    border.color: severe ? Theme.dangerBorder : Theme.tint(Theme.warn, 0.45)
    Accessible.role: Accessible.AlertMessage
    Accessible.name: active ? error.title : ""
    Accessible.description: active ? error.message : ""

    GridLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.touch ? 14 : 12
        columns: root.touch ? 1 : 3
        columnSpacing: 12
        rowSpacing: 10

        Icon {
            Layout.alignment: Qt.AlignTop
            visible: !root.touch
            name: root.iconName
            size: 18
            color: root.severe ? Theme.danger : Theme.warn
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                spacing: 8
                Icon {
                    visible: root.touch
                    name: root.iconName
                    size: 18
                    color: root.severe ? Theme.danger : Theme.warn
                }
                Text {
                    Layout.fillWidth: true
                    text: root.active ? root.error.title : ""
                    wrapMode: Text.Wrap
                    font.family: Theme.sans
                    font.pixelSize: root.touch ? Theme.fontXl : Theme.fontLg
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.active ? root.error.message : ""
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: root.touch ? Theme.fontLg : Theme.fontMd
                lineHeight: 1.15
                color: Theme.text
            }
            AppButton {
                visible: root.active && root.error.detail !== ""
                variant: "link"
                text: root.detailsOpen ? qsTr("Hide details") : qsTr("Details")
                onClicked: root.detailsOpen = !root.detailsOpen
            }
            TextEdit {
                Layout.fillWidth: true
                visible: root.detailsOpen
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                text: root.active ? root.error.detail : ""
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                color: Theme.textMuted
            }
        }

        GridLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: root.touch
            columns: root.touch ? 2 : 1
            rowSpacing: 6
            columnSpacing: 8
            AppButton {
                Layout.fillWidth: true
                visible: root.active && root.error.primaryAction !== ErrorInfo.None
                variant: "primary"
                touch: root.touch
                text: root.active ? root.error.primaryLabel : ""
                onClicked: root.actionTriggered(root.error.primaryAction)
            }
            AppButton {
                Layout.fillWidth: true
                visible: root.active && root.error.secondaryAction !== ErrorInfo.None
                touch: root.touch
                text: root.active ? root.error.secondaryLabel : ""
                onClicked: root.actionTriggered(root.error.secondaryAction)
            }
        }
    }
}
