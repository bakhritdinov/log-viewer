import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// "Save the changes?" when leaving a form: don't save · cancel · save.
// Focus starts on "Cancel"; Esc cancels.
Popup {
    id: root

    property string title
    property string message: qsTr("Without saving they are lost.")

    signal discardRequested()
    signal saveRequested()

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent ? parent.width - 48 : 440)
    padding: 20
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Theme.overlay }
    onOpened: keepEditing.forceActiveFocus()

    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: ColumnLayout {
        spacing: 12
        Accessible.role: Accessible.AlertMessage
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
            wrapMode: Text.Wrap
            text: root.message
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }
        RowLayout {
            Layout.topMargin: 8
            spacing: 8
            AppButton {
                id: discardButton
                variant: "ghost"
                text: qsTr("Don't save")
                onClicked: root.discardRequested()
                contentItem: Text {
                    text: discardButton.text
                    font: discardButton.font
                    color: Theme.dangerText
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Item { Layout.fillWidth: true }
            AppButton { id: keepEditing; text: qsTr("Cancel"); onClicked: root.close() }
            AppButton { variant: "primary"; text: qsTr("Save"); onClicked: root.saveRequested() }
        }
    }
}
