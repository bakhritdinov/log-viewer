pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The Settings section: environments, language, appearance, about. The
// screens behind each row come in the settings step of stage 7.
ColumnLayout {
    id: root

    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 56
        color: Theme.surface
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Settings")
            font.family: Theme.sans
            font.pixelSize: Theme.fontXl + 2
            font.weight: Font.DemiBold
            color: Theme.textStrong
            Accessible.role: Accessible.Heading
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: body.implicitHeight + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: body
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 8

            SectionLabel { Layout.leftMargin: 4; text: qsTr("Connections") }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: envColumn.implicitHeight
                radius: Theme.radiusLg
                color: Theme.surface
                border.width: 1
                border.color: Theme.border
                clip: true
                Column {
                    id: envColumn
                    width: parent.width
                    Repeater {
                        model: Session.environments
                        delegate: AbstractButton {
                            id: env
                            required property string id
                            required property string name
                            required property string color
                            required property string host
                            required property bool current
                            width: envColumn.width
                            implicitHeight: 60
                            Accessible.name: name
                            onClicked: if (!current) Session.switchEnvironment(id)
                            background: Rectangle { color: env.pressed ? Theme.subtle : "transparent" }
                            contentItem: RowLayout {
                                spacing: 12
                                EnvironmentBadge { Layout.leftMargin: 12; name: env.name; tint: env.color; touch: true }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: env.host !== "" ? env.host : qsTr("Not set up")
                                        elide: Text.ElideRight
                                        font.family: Theme.mono
                                        font.pixelSize: Theme.fontMd
                                        color: Theme.textStrong
                                    }
                                    Text {
                                        visible: env.current
                                        text: qsTr("Active")
                                        font.family: Theme.sans
                                        font.pixelSize: Theme.fontSm
                                        color: Theme.successText
                                    }
                                }
                                Icon { Layout.rightMargin: 12; visible: env.current; name: "check"; size: 18; color: Theme.success }
                            }
                        }
                    }
                }
            }

            SectionLabel { Layout.leftMargin: 4; Layout.topMargin: 12; text: qsTr("Language · Til · Language") }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: Language.languages
                    delegate: AbstractButton {
                        id: lang
                        required property var modelData
                        readonly property bool current: Language.code === modelData.code
                        Layout.fillWidth: true
                        implicitHeight: 48
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.name
                        Accessible.checked: current
                        onClicked: Language.code = modelData.code
                        background: Rectangle {
                            radius: Theme.radiusLg
                            color: lang.current ? Theme.successSoft : (lang.pressed ? Theme.hover : Theme.subtle)
                            border.width: 1
                            border.color: lang.current ? Theme.successBorder : Theme.border
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Flag { anchors.verticalCenter: parent.verticalCenter; code: lang.modelData.code; flagWidth: 20 }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: lang.modelData.name
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontLg
                                    font.weight: Font.Medium
                                    color: lang.current ? Theme.successText : Theme.textStrong
                                }
                            }
                        }
                    }
                }
            }

            SectionLabel { Layout.leftMargin: 4; Layout.topMargin: 12; text: qsTr("Theme") }
            SegmentedControl {
                Layout.fillWidth: true
                touch: true
                fill: true
                accessibleName: qsTr("Theme")
                model: [{ label: qsTr("Dark"), value: "dark" }, { label: qsTr("Light"), value: "light" },
                        { label: qsTr("As in the system"), value: "system" }]
                value: Session.prefs.theme
                onActivated: v => Session.prefs.theme = v
            }

            SectionLabel { Layout.leftMargin: 4; Layout.topMargin: 12; text: qsTr("About") }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                AppLogo { size: 44 }
                Text {
                    text: "LogViewer " + Updates.currentVersion
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }
        }
    }
}
