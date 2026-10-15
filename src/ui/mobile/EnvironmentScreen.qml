pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// One environment on the whole screen: name and colour, Grafana URL and the
// datasource UID, authorization, and "Test and save" pinned to the bottom (it
// rises over the keyboard). The test shows its steps; a failed one offers to
// test again or save anyway. Leaving with changes asks first.
SettingsScreen {
    id: root

    signal done()
    signal notice(string text)

    // "" a new environment (named initialName, e.g. from a share link).
    property string environmentId
    property string initialName
    // Saving waits for the test to pass.
    property bool saveAfterTest: false
    // Own labels instead of the automatic ones (on when the environment has them).
    property bool ownLabels: false

    function leave() {
        if (editor.dirty) leaveDialog.open()
        else root.done()
    }
    function testAndSave() {
        saveAfterTest = true
        editor.testConnection()
    }
    function save() {
        const name = editor.name
        if (editor.save(true)) {
            root.notice(qsTr("Connected to %1").arg(name))
            root.done()
        }
    }

    title: editor.isNew ? qsTr("New environment") : editor.name
    onBackRequested: leave()
    Component.onCompleted: {
        if (environmentId !== "") { editor.load(environmentId); return }
        editor.createNew()
        if (initialName !== "") editor.name = initialName
    }

    EnvironmentEditor {
        id: editor
        onLoaded: root.ownLabels = editor.nsLabel !== "" || editor.appLabel !== ""
        onTestChanged: {
            if (editor.testState === EnvironmentEditor.Passed && root.saveAfterTest) { root.saveAfterTest = false; root.save() }
            else if (editor.testState === EnvironmentEditor.Failed) root.saveAfterTest = false
        }
    }

    Field {
        label: qsTr("Name")
        AppTextField {
            Layout.fillWidth: true
            touch: true
            font.pixelSize: 16
            text: editor.name
            onTextEdited: editor.name = text
            Accessible.name: qsTr("Name")
        }
    }
    Field {
        label: qsTr("Label colour")
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: editor.colors
                delegate: AbstractButton {
                    id: swatch
                    required property string modelData
                    width: 44; height: 44
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData
                    Accessible.checked: editor.color === modelData
                    onClicked: editor.color = modelData
                    background: Rectangle {
                        radius: 22
                        color: swatch.modelData
                        border.width: editor.color === swatch.modelData ? 3 : 0
                        border.color: Theme.textStrong
                    }
                }
            }
        }
    }
    Field {
        label: qsTr("Grafana URL")
        AppTextField {
            Layout.fillWidth: true
            touch: true
            mono: true
            font.pixelSize: 16
            placeholderText: "https://grafana.example.com"
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            text: editor.url
            onTextEdited: editor.url = text
            Accessible.name: qsTr("Grafana URL")
        }
    }
    Field {
        label: qsTr("Logs datasource UID")
        hint: qsTr("Grafana → Connections → Data sources → the last part of the URL")
        AppTextField {
            Layout.fillWidth: true
            touch: true
            mono: true
            font.pixelSize: 16
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            text: editor.datasourceUid
            onTextEdited: editor.datasourceUid = text
            Accessible.name: qsTr("Datasource UID")
        }
    }
    Field {
        label: qsTr("Authorization")
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Authorization")
            model: [{ label: qsTr("Password"), value: EnvironmentEditor.Basic },
                    { label: qsTr("Token"), value: EnvironmentEditor.Token },
                    { label: qsTr("None"), value: EnvironmentEditor.None }]
            value: editor.auth
            onActivated: v => editor.auth = v
        }
    }
    Field {
        visible: editor.auth === EnvironmentEditor.Basic
        label: qsTr("User")
        AppTextField {
            Layout.fillWidth: true
            touch: true
            font.pixelSize: 16
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            text: editor.user
            onTextEdited: editor.user = text
            Accessible.name: qsTr("User")
        }
    }
    Field {
        visible: editor.auth === EnvironmentEditor.Basic
        label: qsTr("Password")
        AppTextField {
            Layout.fillWidth: true
            touch: true
            font.pixelSize: 16
            echoMode: TextInput.Password
            text: editor.password
            onTextEdited: editor.password = text
            Accessible.name: qsTr("Password")
        }
    }
    Field {
        visible: editor.auth === EnvironmentEditor.Token
        label: qsTr("API token")
        AppTextField {
            Layout.fillWidth: true
            touch: true
            mono: true
            font.pixelSize: 16
            echoMode: TextInput.Password
            text: editor.token
            onTextEdited: editor.token = text
            Accessible.name: qsTr("API token")
        }
    }
    Text {
        Layout.fillWidth: true
        visible: editor.auth !== EnvironmentEditor.None
        text: Qt.platform.os === "wasm"
              ? qsTr("In the browser the password is kept in the site's storage on this phone.")
              : editor.secretsSecure ? qsTr("The password is kept in the system keychain.")
                                     : qsTr("The system keychain is unavailable: the password is kept in the settings of this device.")
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }

    // Labels for logs that do not use the usual ones.
    SettingRow {
        isSwitch: true
        title: qsTr("Own labels")
        hint: qsTr("Found automatically when off (_namespace / _appName and similar)")
        switchChecked: root.ownLabels
        onSwitched: checked => {
            root.ownLabels = checked
            if (!checked) { editor.nsLabel = ""; editor.appLabel = "" }
        }
    }
    ColumnLayout {
        id: labels
        Layout.fillWidth: true
        visible: root.ownLabels
        spacing: 10
        Field {
            label: qsTr("Namespace label")
            AppTextField {
                Layout.fillWidth: true
                touch: true
                mono: true
                font.pixelSize: 16
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                text: editor.nsLabel
                onTextEdited: editor.nsLabel = text
                Accessible.name: qsTr("Namespace label")
            }
        }
        Field {
            label: qsTr("App label")
            AppTextField {
                Layout.fillWidth: true
                touch: true
                mono: true
                font.pixelSize: 16
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                text: editor.appLabel
                onTextEdited: editor.appLabel = text
                Accessible.name: qsTr("App label")
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: editor.validationError !== ""
        text: editor.validationError
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: Theme.fontMd
        color: Theme.dangerText
    }

    // The test: its steps as they pass, or what failed.
    Rectangle {
        Layout.fillWidth: true
        visible: editor.testState === EnvironmentEditor.Testing || editor.testState === EnvironmentEditor.Passed
        implicitHeight: steps.implicitHeight + 24
        radius: Theme.radiusLg
        color: editor.testState === EnvironmentEditor.Passed ? Theme.successSoft : Theme.tint(Theme.accent, 0.06)
        border.width: 1
        border.color: editor.testState === EnvironmentEditor.Passed ? Theme.successBorder : Theme.accentBorder
        ColumnLayout {
            id: steps
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: editor.testState === EnvironmentEditor.Passed ? qsTr("The connection works") : qsTr("Testing the connection…")
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }
            Repeater {
                model: [
                    { text: editor.testStep >= 1 ? qsTr("Server responds · %1 ms").arg(editor.testServerMs) : qsTr("Connecting to the server…"), done: editor.testStep >= 1 },
                    { text: qsTr("Login and datasource accepted"), done: editor.testStep >= 1 },
                    { text: qsTr("Finding namespaces"), done: editor.testState === EnvironmentEditor.Passed },
                ]
                delegate: RowLayout {
                    id: step
                    required property var modelData
                    spacing: 8
                    Icon { name: step.modelData.done ? "check" : "clock"; size: 14; color: step.modelData.done ? Theme.successText : Theme.textMuted }
                    Text {
                        Layout.fillWidth: true
                        text: step.modelData.text
                        wrapMode: Text.Wrap
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontMd
                        color: step.modelData.done ? Theme.text : Theme.textMuted
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: editor.testState === EnvironmentEditor.Passed && editor.testMessage !== ""
                text: editor.testMessage
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.text
            }
        }
    }
    ErrorBanner {
        Layout.fillWidth: true
        visible: editor.testState === EnvironmentEditor.Failed
        touch: true
        error: editor.testError
        onActionTriggered: editor.testConnection()
    }

    // Deleting, at the end of the form.
    AppButton {
        Layout.fillWidth: true
        Layout.topMargin: 16
        visible: !editor.isNew && editor.canRemove
        touch: true
        variant: "danger"
        text: qsTr("Delete the environment")
        onClicked: removeDialog.open()
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 16
        visible: !editor.isNew && !editor.canRemove
        text: qsTr("This is the only environment")
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }

    footer: [
        AppButton {
            Layout.fillWidth: true
            visible: editor.testState !== EnvironmentEditor.Testing && editor.testState !== EnvironmentEditor.Failed
            touch: true
            variant: "primary"
            text: qsTr("Test and save")
            onClicked: root.testAndSave()
        },
        AppButton {
            Layout.fillWidth: true
            visible: editor.testState === EnvironmentEditor.Testing
            touch: true
            text: qsTr("Cancel the test")
            onClicked: { root.saveAfterTest = false; editor.cancelTest() }
        },
        AppButton {
            Layout.fillWidth: true
            visible: editor.testState === EnvironmentEditor.Failed
            touch: true
            variant: "primary"
            text: qsTr("Test again")
            onClicked: root.testAndSave()
        },
        AppButton {
            Layout.fillWidth: true
            visible: editor.testState === EnvironmentEditor.Failed
            touch: true
            text: qsTr("Save without the test")
            onClicked: root.save()
        }
    ]

    ConfirmDialog {
        id: removeDialog
        title: qsTr("Delete the environment %1?").arg(editor.name)
        message: qsTr("Its address and password are removed from the phone. Saved queries stay.")
        confirmText: qsTr("Delete")
        onConfirmed: { const name = editor.name; if (editor.remove()) { root.notice(qsTr("Environment %1 deleted").arg(name)); root.done() } }
    }

    // Leaving with changes: save, keep editing or drop them (stacked: the
    // labels are long).
    Popup {
        id: leaveDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent ? parent.width - 32 : 360, 400)
        padding: 20
        modal: true
        focus: true
        Overlay.modal: Rectangle { color: Theme.overlay }
        background: Rectangle { radius: Theme.radiusLg + 4; color: Theme.surface; border.width: 1; border.color: Theme.border }
        contentItem: ColumnLayout {
            spacing: 10
            Accessible.role: Accessible.Dialog
            Accessible.name: leaveTitle.text
            Text {
                id: leaveTitle
                Layout.fillWidth: true
                text: editor.isNew ? qsTr("Save the new environment?") : qsTr("Save the changes to %1?").arg(editor.name)
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: Theme.fontXl
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }
            AppButton {
                Layout.fillWidth: true
                Layout.topMargin: 6
                touch: true
                variant: "primary"
                text: qsTr("Save")
                onClicked: { leaveDialog.close(); root.save() }
            }
            AppButton {
                Layout.fillWidth: true
                touch: true
                text: qsTr("Keep editing")
                onClicked: leaveDialog.close()
            }
            AppButton {
                Layout.fillWidth: true
                touch: true
                variant: "danger"
                text: qsTr("Don't save")
                onClicked: { leaveDialog.close(); root.done() }
            }
        }
    }

    component Field: ColumnLayout {
        id: field
        property string label
        property string hint
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: field.label
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            font.weight: Font.Medium
            color: Theme.text
        }
        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            visible: field.hint !== ""
            text: field.hint
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
    }
}
