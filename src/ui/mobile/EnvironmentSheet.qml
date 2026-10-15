pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The environment, from the badge in the bar. The source stays when the new
// environment has it; otherwise the source sheet opens (sourceMissing).
BottomSheet {
    id: root

    signal settingsRequested()
    signal sourceMissing()

    // The source to look for once the new environment's namespaces are found.
    property string keptNamespace
    property string keptApp
    property bool checking: false
    Connections {
        target: Session
        enabled: root.checking
        function onDiscoveringChanged() {
            if (Session.discovering) return
            root.checking = false
            if (Session.appsOf(root.keptNamespace).indexOf(root.keptApp) < 0) root.sourceMissing()
            else if (Session.namespaceName !== root.keptNamespace || Session.app !== root.keptApp)
                Session.selectSource(root.keptNamespace, root.keptApp)
        }
    }

    function pick(id) {
        keptNamespace = Session.namespaceName
        keptApp = Session.app
        checking = true
        Session.switchEnvironment(id)
        close()
    }

    title: qsTr("Environment")

    Repeater {
        model: Session.environments
        delegate: AbstractButton {
            id: env
            required property var model
            readonly property bool failing: model.current && Session.hasError && Session.error.kind === ErrorInfo.Unreachable
            Layout.fillWidth: true
            implicitHeight: 64
            Accessible.role: Accessible.RadioButton
            Accessible.name: model.name
            Accessible.checked: model.current
            onClicked: model.current ? root.close() : root.pick(model.id)
            background: Rectangle { color: env.pressed ? Theme.subtle : env.model.current ? Theme.accentSoft : "transparent" }
            contentItem: RowLayout {
                spacing: 12
                EnvironmentBadge {
                    Layout.leftMargin: 16
                    name: env.model.name
                    tint: env.model.color
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        visible: env.model.host !== ""
                        text: env.model.host
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontLg
                        color: Theme.textStrong
                    }
                    Text {
                        Layout.fillWidth: true
                        text: !env.model.configured ? qsTr("Not set up")
                            : env.failing ? qsTr("No connection")
                            : env.model.current ? qsTr("Active") : qsTr("Set up")
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        color: env.failing ? Theme.dangerText : env.model.current ? Theme.successText : Theme.textMuted
                    }
                }
                Icon { Layout.rightMargin: 16; visible: env.model.current; name: "check"; size: 18; color: Theme.accentText }
            }
        }
    }

    footer: AppButton {
        Layout.fillWidth: true
        touch: true
        iconName: "settings"
        text: qsTr("Manage environments")
        onClicked: { root.close(); root.settingsRequested() }
    }
}
