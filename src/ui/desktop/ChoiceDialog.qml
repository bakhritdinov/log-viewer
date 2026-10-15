import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// A question with two ways forward and "Cancel" (e.g. import: add or replace).
Popup {
    id: root

    property string title
    property string message
    property string primaryText
    property string secondaryText

    signal primaryChosen()
    signal secondaryChosen()

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent ? parent.width - 48 : 440)
    padding: 20
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Theme.overlay }
    onOpened: primaryButton.forceActiveFocus()

    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: ColumnLayout {
        spacing: 12
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.title
            font.family: Theme.sans
            font.pixelSize: Theme.fontXl
            font.weight: Font.DemiBold
            color: Theme.textStrong
        }
        Text {
            Layout.fillWidth: true
            visible: root.message !== ""
            wrapMode: Text.Wrap
            text: root.message
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }
        RowLayout {
            Layout.topMargin: 8
            spacing: 8
            Item { Layout.fillWidth: true }
            AppButton { text: qsTr("Cancel"); onClicked: root.close() }
            AppButton { text: root.secondaryText; onClicked: { root.close(); root.secondaryChosen() } }
            AppButton { id: primaryButton; variant: "primary"; text: root.primaryText; onClicked: { root.close(); root.primaryChosen() } }
        }
    }
}
