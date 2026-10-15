import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Link to the current selection: fixed or relative period, optionally the
// selected entry. The link names the environment, never its address or secrets.
Popup {
    id: root

    property bool fixedRange: true
    property bool includeSelection: true
    readonly property bool hasSelection: Session.selectedEntry.valid
    readonly property string link: opened ? Session.shareLink(fixedRange || Session.timeRangeAbsolute,
                                                              includeSelection && hasSelection) : ""

    width: 520
    padding: 16
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onOpened: copied.running = false

    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    Clipboard { id: clipboard }
    Timer { id: copied; interval: 1500 }

    contentItem: ColumnLayout {
        spacing: 14
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Link to the selection")

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            AppTextField {
                Layout.fillWidth: true
                mono: true
                readOnly: true
                text: root.link
                Accessible.name: qsTr("Link")
                // Show where the link starts (host, environment), not its tail.
                onTextChanged: cursorPosition = 0
            }
            AppButton {
                id: copyButton
                implicitHeight: Theme.inputHeight      // as tall as the link field
                variant: "primary"
                iconName: copied.running ? "check" : "copy"
                text: copied.running ? qsTr("Copied") : qsTr("Copy")
                onClicked: { clipboard.copy(root.link); copied.restart() }
                // Done: a green outline instead of the filled button, for 1.5 s.
                contentItem: Row {
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: copyButton.iconName
                        size: 14
                        strokeWidth: copied.running ? 2.6 : 2
                        color: copied.running ? Theme.successText : Theme.textOnAccent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: copyButton.text
                        font: copyButton.font
                        color: copied.running ? Theme.successText : Theme.textOnAccent
                    }
                }
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: copied.running ? Theme.successSoft : (copyButton.hovered ? Theme.successBorder : Theme.successStrong)
                    border.width: 1
                    border.color: Theme.successBorder
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: !Session.timeRangeAbsolute
            SectionLabel { text: qsTr("Period in the link") }
            AppRadioButton {
                // Long labels wrap inside the popup instead of widening it.
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                checked: root.fixedRange
                onToggled: root.fixedRange = true
                text: qsTr("Freeze %1 – %2 — a colleague sees exactly the same")
                      .arg(Session.absoluteFromText).arg(Session.absoluteToText)
            }
            AppRadioButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                checked: !root.fixedRange
                onToggled: root.fixedRange = false
                text: qsTr("Relative: “%1” at the moment of opening").arg(Session.timeRangeLabel)
            }
        }

        AppCheckBox {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            visible: root.hasSelection
            checked: root.includeSelection
            onToggled: root.includeSelection = checked
            text: qsTr("Highlight the selected entry %1").arg(Session.selectedEntry.dateTimeText)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Icon { Layout.alignment: Qt.AlignTop; name: "lock"; size: 14; color: Theme.textMuted }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: qsTr("The link has no Grafana address or passwords — only the environment by name, the source, the query and the period. The recipient needs an environment named “%1”.")
                      .arg(Session.environmentName)
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                lineHeight: 1.2
                color: Theme.textMuted
            }
        }
    }
}
