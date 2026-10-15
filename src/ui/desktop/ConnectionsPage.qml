pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Environments (any number, DEV and PROD by default): URL, datasource UID,
// credentials, a connection test, colour.
ColumnLayout {
    id: root

    signal done()

    spacing: 0

    EnvironmentEditor { id: editor }

    function createNamed(name) {
        editor.createNew()
        editor.name = name
    }
    function showLabels() { advanced.open = true }
    // Runs `then` now, or after the user decides about unsaved changes.
    function confirmLeave(then) {
        if (!editor.dirty) { then(); return }
        unsaved.then = then
        unsaved.open()
    }

    Component.onCompleted: editor.load(Session.environmentId)
    onVisibleChanged: if (visible) editor.load(Session.environmentId)

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 18

            // Environment tabs
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 8
                Repeater {
                    model: Session.environments
                    delegate: AbstractButton {
                        id: envTab
                        required property string id
                        required property string name
                        required property string color
                        readonly property bool selected: !editor.isNew && editor.environmentId === envTab.id
                        implicitHeight: 34
                        implicitWidth: tabRow.implicitWidth + leftPadding + rightPadding
                        leftPadding: 14
                        rightPadding: 14
                        Accessible.role: Accessible.PageTab
                        Accessible.name: envTab.name
                        Accessible.selected: envTab.selected
                        onClicked: if (!envTab.selected) root.confirmLeave(() => editor.load(envTab.id))
                        background: Rectangle {
                            radius: Theme.radiusLg - 2
                            color: envTab.selected ? Theme.tint(envTab.color, 0.1) : "transparent"
                            border.width: 1
                            border.color: envTab.selected ? Theme.tint(envTab.color, 0.7) : Theme.border
                        }
                        contentItem: Row {
                            id: tabRow
                            spacing: 8
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: envTab.color }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: envTab.name
                                font.family: Theme.sans
                                font.pixelSize: Theme.fontMd
                                font.weight: Font.DemiBold
                                color: Theme.textStrong
                            }
                        }
                    }
                }
                AppButton {
                    id: newTab
                    implicitHeight: 34
                    variant: "ghost"
                    iconName: "plus"
                    text: editor.isNew ? qsTr("New") : qsTr("Environment")
                    onClicked: if (!editor.isNew) root.confirmLeave(() => editor.createNew())
                    background: Rectangle {
                        radius: Theme.radiusLg - 2
                        color: editor.isNew ? Theme.accentSoft : (newTab.hovered ? Theme.subtle : "transparent")
                        border.width: 1
                        border.color: editor.isNew ? Theme.focusRing : Theme.border
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                columns: 2
                columnSpacing: 16
                rowSpacing: 14

                Field {
                    label: qsTr("Name")
                    AppTextField {
                        Layout.fillWidth: true
                        text: editor.name
                        onTextEdited: editor.name = text
                        Accessible.name: qsTr("Name")
                    }
                }
                Field {
                    label: qsTr("Label colour")
                    Row {
                        spacing: 8
                        Accessible.role: Accessible.RadioButton
                        Repeater {
                            model: editor.colors
                            delegate: AbstractButton {
                                id: swatch
                                required property string modelData
                                implicitWidth: 28
                                implicitHeight: 28
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: swatch.modelData
                                Accessible.checked: editor.color === swatch.modelData
                                onClicked: editor.color = swatch.modelData
                                background: Rectangle {
                                    radius: 14
                                    color: swatch.modelData
                                    border.width: 2
                                    border.color: editor.color === swatch.modelData ? Theme.textStrong
                                                : swatch.visualFocus ? Theme.focusRing : "transparent"
                                }
                            }
                        }
                    }
                }
                Field {
                    Layout.columnSpan: 2
                    label: qsTr("Grafana URL")
                    AppTextField {
                        Layout.fillWidth: true
                        mono: true
                        placeholderText: "https://grafana.example.com"
                        text: editor.url
                        onTextEdited: editor.url = text
                        inputMethodHints: Qt.ImhUrlCharactersOnly
                        Accessible.name: qsTr("Grafana URL")
                    }
                }
                Field {
                    Layout.columnSpan: 2
                    label: qsTr("Datasource UID (Loki / VictoriaLogs)")
                    hint: qsTr("Grafana → Connections → Data sources → your source, the last part of the URL")
                    AppTextField {
                        Layout.fillWidth: true
                        mono: true
                        text: editor.datasourceUid
                        onTextEdited: editor.datasourceUid = text
                        Accessible.name: qsTr("Datasource UID")
                    }
                }
                Field {
                    Layout.columnSpan: 2
                    label: qsTr("Authorization")
                    SegmentedControl {
                        accessibleName: qsTr("Authorization")
                        model: [{ label: qsTr("Login and password"), value: EnvironmentEditor.Basic },
                                { label: qsTr("API token"), value: EnvironmentEditor.Token },
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
                        mono: true
                        text: editor.user
                        onTextEdited: editor.user = text
                        Accessible.name: qsTr("User")
                    }
                }
                Field {
                    visible: editor.auth === EnvironmentEditor.Basic
                    label: qsTr("Password")
                    SecretField {
                        text: editor.password
                        onTextEdited: editor.password = text
                        Accessible.name: qsTr("Password")
                    }
                }
                Field {
                    visible: editor.auth === EnvironmentEditor.Token
                    Layout.columnSpan: 2
                    label: qsTr("API token")
                    SecretField {
                        text: editor.token
                        onTextEdited: editor.token = text
                        Accessible.name: qsTr("API token")
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                visible: editor.validationError !== ""
                text: editor.validationError
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.dangerText
                Accessible.role: Accessible.AlertMessage
            }

            // Advanced: the labels of namespace and app (automatic by default).
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 10
                property bool open: editor.nsLabel !== "" || editor.appLabel !== ""
                id: advanced
                AppButton {
                    variant: "ghost"
                    leftPadding: 0
                    text: qsTr("Advanced")
                    Accessible.name: text
                    onClicked: advanced.open = !advanced.open
                    contentItem: Row {
                        spacing: 6
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevronRight"; size: 12
                            color: Theme.text
                            rotation: advanced.open ? 90 : 0
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Advanced")
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                    }
                }
                GridLayout {
                    visible: advanced.open
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 8
                    Field {
                        label: qsTr("Namespace label")
                        AppTextField {
                            mono: true
                            placeholderText: qsTr("found automatically")
                            text: editor.nsLabel
                            onTextEdited: editor.nsLabel = text
                            Accessible.name: qsTr("Namespace label")
                        }
                    }
                    Field {
                        label: qsTr("App label")
                        AppTextField {
                            mono: true
                            placeholderText: qsTr("found automatically")
                            text: editor.appLabel
                            onTextEdited: editor.appLabel = text
                            Accessible.name: qsTr("App label")
                        }
                    }
                }
                RowLayout {
                    visible: advanced.open
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: qsTr("Empty fields: the labels are found automatically (_namespace / _appName and similar). Set both when your logs use other labels, e.g. kubernetes_namespace and app.")
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }
                    AppButton {
                        visible: editor.nsLabel !== "" || editor.appLabel !== ""
                        text: qsTr("Find automatically")
                        onClicked: { editor.nsLabel = ""; editor.appLabel = "" }
                    }
                }
            }

            // Connection test
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                visible: editor.testState !== EnvironmentEditor.Failed
                implicitHeight: testRow.implicitHeight + 24
                radius: Theme.radiusLg - 2
                color: editor.testState === EnvironmentEditor.Passed ? Theme.successSoft
                     : editor.testState === EnvironmentEditor.Testing ? Theme.tint(Theme.accent, 0.06) : "transparent"
                border.width: 1
                border.color: editor.testState === EnvironmentEditor.Passed ? Theme.successBorder
                            : editor.testState === EnvironmentEditor.Testing ? Theme.accentBorder : Theme.border
                RowLayout {
                    id: testRow
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: 14
                    spacing: 12
                    Icon {
                        visible: editor.testState === EnvironmentEditor.Passed
                        name: "check"
                        size: 18
                        strokeWidth: 2.4
                        color: Theme.success
                    }
                    Icon {
                        visible: editor.testState === EnvironmentEditor.Testing
                        name: "refresh"
                        size: 18
                        color: Theme.accent
                        RotationAnimator on rotation {
                            running: editor.testState === EnvironmentEditor.Testing
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: editor.testState === EnvironmentEditor.Passed ? qsTr("The connection works")
                                : editor.testState === EnvironmentEditor.Testing ? editor.testMessage
                                : qsTr("Test the connection before saving")
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                            color: Theme.textStrong
                        }
                        // Steps as they pass: where a problem is shows at once.
                        Column {
                            visible: editor.testState === EnvironmentEditor.Testing
                            Layout.topMargin: 4
                            spacing: 3
                            Repeater {
                                model: [
                                    { text: editor.testStep >= 1 ? qsTr("Server responds · %1 ms").arg(editor.testServerMs) : qsTr("Connecting to the server…"), state: editor.testStep >= 1 ? 2 : 1 },
                                    { text: qsTr("Login and datasource accepted"), state: editor.testStep >= 1 ? 2 : 0 },
                                    { text: qsTr("Finding namespaces and apps"), state: editor.testStep >= 1 ? 1 : 0 },
                                ]
                                delegate: Text {
                                    required property var modelData
                                    text: (modelData.state === 2 ? "✓ " : modelData.state === 1 ? "… " : "○ ") + modelData.text
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontSm
                                    color: modelData.state === 2 ? Theme.success : modelData.state === 1 ? Theme.text : Theme.textMuted
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: editor.testState === EnvironmentEditor.Passed
                            text: editor.testMessage
                            wrapMode: Text.Wrap
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                            color: Theme.textMuted
                        }
                    }
                    AppButton {
                        visible: editor.testState !== EnvironmentEditor.Testing
                        text: editor.testState === EnvironmentEditor.Passed ? qsTr("Test again") : qsTr("Test connection")
                        onClicked: editor.testConnection()
                    }
                    AppButton {
                        visible: editor.testState === EnvironmentEditor.Testing
                        text: qsTr("Cancel the test")
                        onClicked: editor.cancelTest()
                    }
                }
            }
            ErrorBanner {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                visible: editor.testState === EnvironmentEditor.Failed
                error: editor.testError
                radius: Theme.radiusLg - 2
                onActionTriggered: editor.testConnection()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 20
                spacing: 10
                Icon {
                    Layout.alignment: Qt.AlignTop
                    name: editor.secretsSecure ? "lock" : "warning"
                    color: editor.secretsSecure ? Theme.textMuted : Theme.warnText
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: editor.secretsSecure
                          ? qsTr("Passwords and tokens are kept in the system keychain (Keychain / Credential Manager), not in the settings file.")
                          : qsTr("The system keychain is unavailable: passwords and tokens are kept in the settings file of this device.")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: editor.secretsSecure ? Theme.textMuted : Theme.warnText
                }
            }
        }
    }

    // Footer
    Rectangle {
        Layout.fillWidth: true
        // Inside the dialog's border; only the dialog's corner is rounded.
        Layout.rightMargin: 1
        Layout.bottomMargin: 1
        implicitHeight: 62
        color: Theme.bg
        bottomRightRadius: Theme.radiusLg + 1
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 8
            // The only environment cannot go; the reason shows on hover.
            Item {
                visible: !editor.isNew
                implicitWidth: deleteButton.implicitWidth
                implicitHeight: deleteButton.implicitHeight
                HoverHandler { id: deleteHover }
                AppButton {
                    id: deleteButton
                    variant: "danger"
                    enabled: editor.canRemove
                    text: qsTr("Delete environment")
                    onClicked: confirmRemove.open()
                }
                AppToolTip {
                    visible: deleteHover.hovered && !deleteButton.enabled
                    text: qsTr("The only environment cannot be deleted")
                }
            }
            Item { Layout.fillWidth: true }
            AppButton { text: qsTr("Cancel"); onClicked: root.confirmLeave(() => root.done()) }
            AppButton {
                visible: editor.testState === EnvironmentEditor.Failed
                variant: "ghost"
                text: qsTr("Save without the test")
                onClicked: if (editor.save(true)) root.done()
            }
            AppButton {
                variant: "primary"
                text: qsTr("Save and connect")
                enabled: editor.testState !== EnvironmentEditor.Testing
                onClicked: if (editor.save(true)) root.done()
            }
        }
    }

    // Leaving the form with unsaved changes.
    UnsavedChangesDialog {
        id: unsaved
        property var then: null
        title: editor.isNew ? qsTr("Save the new environment?") : qsTr("Save the changes to %1?").arg(editor.name)
        onDiscardRequested: {
            const then = unsaved.then
            unsaved.close()
            if (editor.isNew) editor.createNew(); else editor.load(editor.environmentId)
            if (then) then()
        }
        onSaveRequested: {
            const then = unsaved.then
            unsaved.close()
            if (editor.save(true) && then) then()
        }
    }

    ConfirmDialog {
        id: confirmRemove
        title: qsTr("Delete the environment %1?").arg(editor.name)
        message: qsTr("Its address and credentials are removed from this device. Saved queries of it stay.")
        confirmText: qsTr("Delete environment")
        onConfirmed: editor.remove()
    }

    // A labelled form row.
    component Field: ColumnLayout {
        id: field
        property string label
        property string hint
        default property alias content: slot.data
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: field.label
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            font.weight: Font.Medium
            color: Theme.text
        }
        ColumnLayout { id: slot; Layout.fillWidth: true }
        Text {
            Layout.fillWidth: true
            visible: field.hint !== ""
            text: field.hint
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
    }

    // Password-style input with a show/hide toggle.
    component SecretField: AppTextField {
        id: secret
        property bool revealed: false
        Layout.fillWidth: true
        mono: true
        echoMode: revealed ? TextInput.Normal : TextInput.Password
        rightPadding: 40
        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconName: "eye"
            label: secret.revealed ? qsTr("Hide") : qsTr("Show")
            checkable: true
            checked: secret.revealed
            onToggled: secret.revealed = checked
        }
    }
}
