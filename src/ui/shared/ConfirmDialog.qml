import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// A short yes/no question in the app's look (destructive actions).
Popup {
    id: root

    property string title
    property string message
    property string confirmText: qsTr("Delete")
    property bool destructive: true

    signal confirmed()

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(420, parent ? parent.width - 48 : 420)
    padding: 20
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle { color: Theme.overlay }
    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: ColumnLayout {
        spacing: 12
        Accessible.role: Accessible.AlertMessage
        Accessible.name: root.title
        Text {
            Layout.fillWidth: true
            text: root.title
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontLg + 1
            font.weight: Font.DemiBold
            color: Theme.textStrong
        }
        Text {
            Layout.fillWidth: true
            visible: root.message !== ""
            text: root.message
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8
            Item { Layout.fillWidth: true }
            AppButton { text: qsTr("Cancel"); onClicked: root.close() }
            AppButton {
                variant: root.destructive ? "danger" : "primary"
                text: root.confirmText
                onClicked: { root.confirmed(); root.close() }
            }
        }
    }
}
