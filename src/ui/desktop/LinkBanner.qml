import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Shown after opening a share link: what was opened, save it or go back.
Rectangle {
    id: root

    signal saveRequested()

    implicitHeight: row.implicitHeight + 16
    color: Theme.accentSoft
    Accessible.role: Accessible.StatusBar
    Accessible.name: label.text

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.accentBorder }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10
        Icon { name: "link"; color: Theme.accent }
        Text {
            id: label
            Layout.fillWidth: true
            text: qsTr("Opened from a link: %1 · %2 / %3 · %4").arg(Session.environmentName)
                  .arg(Session.namespaceName).arg(Session.app).arg(Session.timeRangeLabel)
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.text
        }
        AppButton { text: qsTr("Save as query"); onClicked: root.saveRequested() }
        AppButton { variant: "ghost"; text: qsTr("Back to my selection"); onClicked: Session.dismissLinkBanner() }
    }
}
