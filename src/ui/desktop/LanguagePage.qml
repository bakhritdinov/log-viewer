pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Interface language: applies at once, no restart. Names are always in their
// own language so the list stays readable whichever one is on.
ColumnLayout {
    id: root

    signal done()

    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 24
        Layout.topMargin: 20
        spacing: 10

        Repeater {
            model: Language.languages
            delegate: AbstractButton {
                id: option
                required property var modelData
                readonly property bool current: Language.code === modelData.code
                Layout.fillWidth: true
                implicitHeight: Math.max(64, optionRow.implicitHeight + 20)
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.name
                Accessible.checked: current
                onClicked: Language.code = modelData.code
                background: Rectangle {
                    radius: Theme.radiusLg
                    color: option.current ? Theme.successSoft : "transparent"
                    border.width: 1
                    border.color: option.current ? Theme.successBorder
                                : option.visualFocus ? Theme.focusRing
                                : option.hovered ? Theme.textMuted : Theme.border
                }
                contentItem: RowLayout {
                    id: optionRow
                    spacing: 14
                    Rectangle {
                        Layout.leftMargin: 16
                        implicitWidth: 18
                        implicitHeight: 18
                        radius: 9
                        color: "transparent"
                        border.width: 2
                        border.color: option.current ? Theme.success : Theme.textMuted
                        Rectangle {
                            anchors.centerIn: parent
                            width: 8; height: 8; radius: 4
                            color: option.current ? Theme.success : "transparent"
                        }
                    }
                    Flag {
                        code: option.modelData.code
                        flagWidth: 27
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            Layout.fillWidth: true
                            text: option.modelData.name
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.DemiBold
                            color: Theme.textStrong
                        }
                        Text {
                            Layout.fillWidth: true
                            text: option.modelData.englishName
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                            color: Theme.textMuted
                        }
                    }
                    Text {
                        Layout.rightMargin: 16
                        text: option.modelData.sample
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 8
            implicitHeight: note.implicitHeight + 24
            radius: Theme.radiusMd + 2
            color: Theme.accentSoft
            border.width: 1
            border.color: Theme.accentBorder
            RowLayout {
                id: note
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                Icon { Layout.alignment: Qt.AlignTop; name: "warning"; color: Theme.accent }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                    text: qsTr("The language changes at once, no restart needed. Dates, numbers and month names follow the chosen language. Logs, field names and queries are not translated.")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    color: Theme.text
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

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
            Text {
                Layout.fillWidth: true
                text: qsTr("Default — Russian")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            AppButton { text: qsTr("Close"); onClicked: root.done() }
        }
    }
}
