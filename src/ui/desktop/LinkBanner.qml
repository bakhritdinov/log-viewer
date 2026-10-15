import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Shown after opening a share link: what was opened, save it or go back.
// With `missingEnvironment` set it explains instead why the link did not open.
Rectangle {
    id: root

    property string missingEnvironment     // the link's environment is not set up here

    signal saveRequested()
    signal addEnvironmentRequested(string name)
    signal dismissed()

    readonly property bool missing: missingEnvironment !== ""
    readonly property color _tint: missing ? Theme.warn : Theme.variable

    implicitHeight: row.implicitHeight + 16
    color: Theme.tint(_tint, 0.1)
    Accessible.role: missing ? Accessible.AlertMessage : Accessible.StatusBar
    Accessible.name: label.text

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.tint(root._tint, 0.45) }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10
        Icon { name: root.missing ? "warning" : "link"; color: root.missing ? Theme.warn : Theme.variable }
        Text {
            id: label
            Layout.fillWidth: true
            textFormat: Text.StyledText
            text: root.missing
                  ? qsTr("The link leads to the environment “%1”, which is not set up here. Add an environment with this name and the link opens.").arg(root.missingEnvironment)
                  : qsTr("From a link: <b>%1</b> · %2 / %3 · %4").arg(Session.environmentName)
                    .arg(Session.namespaceName).arg(Session.app).arg(Session.timeRangeLabel)
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textStrong
        }
        AppButton {
            visible: root.missing
            variant: "primary"
            implicitHeight: 28
            text: qsTr("Add environment %1").arg(root.missingEnvironment)
            onClicked: root.addEnvironmentRequested(root.missingEnvironment)
        }
        AppButton {
            visible: !root.missing
            implicitHeight: 28
            text: qsTr("Save as query")
            onClicked: root.saveRequested()
        }
        AppButton {
            variant: "ghost"
            implicitHeight: 28
            text: root.missing ? qsTr("Close") : qsTr("Back to my selection")
            onClicked: root.missing ? root.dismissed() : Session.dismissLinkBanner()
        }
    }
}
