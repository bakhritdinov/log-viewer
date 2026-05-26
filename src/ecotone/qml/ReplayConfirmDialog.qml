import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

// Modal confirmation used for single-message replays. Multi-message contract
// replays go through ReplayByContractDialog which has its own preview step.
Dialog {
    id: root
    title: qsTr("Confirm replay")
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 540

    // Only "one" mode for now — the dialog keeps the property so the caller's
    // contract stays stable if more modes are added later.
    property string mode: "one"
    property string targetId: ""
    property int    affectedCount: 1
    property string envName: ""

    signal confirmed()

    background: Rectangle {
        color: Theme.bgRaised
        border.color: Theme.warn
        border.width: 1
        radius: Theme.rLg
    }

    header: Rectangle {
        color: "transparent"
        implicitHeight: 50
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp2
            Text { text: "↻"; color: Theme.warn; font.pixelSize: Theme.fsXl; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.title; color: Theme.text; font.pixelSize: Theme.fsLg; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    }

    contentItem: ColumnLayout {
        spacing: Theme.sp3

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fsMd
            color: Theme.text
            text: {
                const env = root.envName ? " (" + root.envName + ")" : ""
                return qsTr("Replay this single message back into its channel%1?").arg(env)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: Theme.bgInput
            border.color: Theme.borderMuted
            border.width: 1
            radius: Theme.rSm
            Layout.preferredHeight: detailsCol.implicitHeight + Theme.sp3 * 2
            ColumnLayout {
                id: detailsCol
                anchors.fill: parent
                anchors.margins: Theme.sp3
                spacing: 2
                Label {
                    text: qsTr("Single-message replay — channel does not require FIFO.")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsSm
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Label {
                    visible: root.targetId !== ""
                    text: qsTr("Message ID: %1").arg(root.targetId)
                    color: Theme.textMuted
                    font.family: "Monospace"
                    font.pixelSize: Theme.fsSm
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }
    }

    footer: Rectangle {
        color: "transparent"
        implicitHeight: 60
        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp4
            anchors.rightMargin: Theme.sp4
            spacing: Theme.sp2
            Item { Layout.fillWidth: true }
            SecondaryButton {
                text: qsTr("Cancel")
                Layout.preferredWidth: 110
                onClicked: root.reject()
            }
            PrimaryButton {
                text: qsTr("Replay")
                Layout.preferredWidth: 130
                onClicked: { root.confirmed(); root.accept() }
            }
        }
    }
}
