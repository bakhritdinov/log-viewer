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
                        onClicked: editor.load(envTab.id)
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
                    implicitHeight: 34
                    variant: editor.isNew ? "secondary" : "ghost"
                    iconName: "plus"
                    text: qsTr("Environment")
                    onClicked: editor.createNew()
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

            // Connection test
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                visible: editor.testState !== EnvironmentEditor.Failed
                implicitHeight: testRow.implicitHeight + 24
                radius: Theme.radiusLg - 2
                color: editor.testState === EnvironmentEditor.Passed ? Theme.successSoft : "transparent"
                border.width: 1
                border.color: editor.testState === EnvironmentEditor.Passed ? Theme.successBorder : Theme.border
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
                    BusyIndicator {
                        visible: editor.testState === EnvironmentEditor.Testing
                        running: visible
                        implicitWidth: 18
                        implicitHeight: 18
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
                        enabled: editor.testState !== EnvironmentEditor.Testing
                        text: editor.testState === EnvironmentEditor.Passed ? qsTr("Test again") : qsTr("Test connection")
                        onClicked: editor.testConnection()
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
        implicitHeight: 62
        color: Theme.bg
        radius: Theme.radiusLg + 2
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 8
            AppButton {
                visible: editor.canRemove
                variant: "danger"
                text: qsTr("Delete environment")
                onClicked: confirmRemove.open()
            }
            Item { Layout.fillWidth: true }
            AppButton { text: qsTr("Cancel"); onClicked: root.done() }
            AppButton {
                variant: "primary"
                text: qsTr("Save and connect")
                onClicked: if (editor.save(true)) root.done()
            }
        }
    }

    Dialog {
        id: confirmRemove
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: qsTr("Delete the environment %1?").arg(editor.name)
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: editor.remove()
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
