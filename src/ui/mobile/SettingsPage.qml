pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The Settings section: a list (connections, language, auto refresh,
// appearance / feed / behaviour, about); each row opens its own screen with
// "‹ Settings" to come back.
Item {
    id: root

    signal notice(string text)

    function popToRoot() { while (stack.depth > 1) stack.pop(null) }
    function openEnvironment(id, name) {
        popToRoot()
        stack.push(environmentScreen, { environmentId: id ?? "", initialName: name ?? "" })
    }

    readonly property string densityLabel: Session.prefs.density === "compact" ? qsTr("compact")
                                         : Session.prefs.density === "comfortable" ? qsTr("roomy") : qsTr("normal")
    readonly property string themeLabel: Session.prefs.theme === "light" ? qsTr("Light")
                                       : Session.prefs.theme === "system" ? qsTr("As in the system") : qsTr("Dark")

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: list
        clip: true
        pushEnter: Transition { NumberAnimation { property: "x"; from: stack.width; to: 0; duration: 160; easing.type: Easing.OutCubic } }
        pushExit: Transition { NumberAnimation { property: "x"; from: 0; to: -stack.width * 0.3; duration: 160 } }
        popEnter: Transition { NumberAnimation { property: "x"; from: -stack.width * 0.3; to: 0; duration: 140 } }
        popExit: Transition { NumberAnimation { property: "x"; from: 0; to: stack.width; duration: 140; easing.type: Easing.InCubic } }
    }

    Component {
        id: environmentScreen
        EnvironmentScreen {
            onDone: stack.pop()
            onNotice: text => root.notice(text)
        }
    }
    Component { id: appearanceScreen; AppearanceScreen { onBackRequested: stack.pop() } }
    Component { id: feedScreen; FeedScreen { onBackRequested: stack.pop() } }
    Component { id: behaviourScreen; BehaviourScreen { onBackRequested: stack.pop(); onNotice: text => root.notice(text) } }
    Component { id: aboutScreen; AboutScreen { onBackRequested: stack.pop(); onNotice: text => root.notice(text) } }

    Component {
        id: list
        Rectangle {
            color: Theme.bg
            Rectangle {
                id: bar
                anchors.left: parent.left
                anchors.right: parent.right
                height: 56
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
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: bar.bottom
                anchors.bottom: parent.bottom
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
                    Group {
                        Repeater {
                            model: Session.environments
                            delegate: SettingsLink {
                                id: env
                                required property int index
                                required property var model
                                readonly property bool failing: model.current && Session.hasError && Session.error.kind === ErrorInfo.Unreachable
                                title: model.name
                                first: index === 0
                                onClicked: root.openEnvironment(model.id)
                                leading: EnvironmentBadge { name: env.model.name; tint: env.model.color; touch: true }
                                subtitle: env.model.host !== "" ? env.model.host : qsTr("Not set up")
                                status: !env.model.configured ? "" : env.failing ? qsTr("No connection")
                                      : env.model.current ? qsTr("Active") : qsTr("Set up")
                                statusColor: env.failing ? Theme.dangerText : env.model.current ? Theme.successText : Theme.textMuted
                                showTitle: false
                            }
                        }
                        SettingsLink {
                            title: qsTr("Add an environment")
                            accent: true
                            leading: Icon { name: "plus"; size: 18; color: Theme.accentText }
                            onClicked: root.openEnvironment("")
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
                                Layout.preferredWidth: 1
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

                    SectionLabel { Layout.leftMargin: 4; Layout.topMargin: 12; text: qsTr("Auto refresh") }
                    SegmentedControl {
                        Layout.fillWidth: true
                        touch: true
                        fill: true
                        accessibleName: qsTr("Auto refresh")
                        enabled: !Session.timeRangeAbsolute
                        model: [{ label: qsTr("Off"), value: 0 }, { label: qsTr("5 s"), value: 5 }, { label: qsTr("10 s"), value: 10 },
                                { label: qsTr("30 s"), value: 30 }, { label: qsTr("1 min"), value: 60 }]
                        value: Session.autoRefreshSeconds
                        onActivated: v => Session.autoRefreshSeconds = v
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: Session.timeRangeAbsolute ? qsTr("A fixed period does not change: auto refresh is off.")
                                                        : qsTr("Repeats the search; the entries on screen stay until the new ones come.")
                        wrapMode: Text.Wrap
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }

                    SectionLabel { Layout.leftMargin: 4; Layout.topMargin: 12; text: qsTr("Look and behaviour") }
                    Group {
                        SettingsLink {
                            first: true
                            title: qsTr("Appearance")
                            value: root.themeLabel + " · " + root.densityLabel
                            onClicked: stack.push(appearanceScreen)
                        }
                        SettingsLink {
                            title: qsTr("Feed")
                            value: qsTr("%1 · %n line(s)", "", Session.prefs.messageLines).arg(Session.prefs.logFontSize)
                            onClicked: stack.push(feedScreen)
                        }
                        SettingsLink {
                            title: qsTr("Behaviour")
                            value: Session.prefs.loadStep.toLocaleString(Qt.locale(), "f", 0)
                            onClicked: stack.push(behaviourScreen)
                        }
                    }

                    SectionLabel { Layout.leftMargin: 4; Layout.topMargin: 12; text: qsTr("About") }
                    Group {
                        SettingsLink {
                            first: true
                            title: qsTr("Version and data")
                            value: Updates.currentVersion
                            onClicked: stack.push(aboutScreen)
                        }
                    }
                }
            }
        }
    }

    // Rows in a rounded frame.
    component Group: Rectangle {
        default property alias rows: groupColumn.data
        Layout.fillWidth: true
        implicitHeight: groupColumn.implicitHeight + 2
        radius: Theme.radiusLg
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        clip: true
        Column {
            id: groupColumn
            x: 1
            y: 1
            width: parent.width - 2
        }
    }

    // A row that opens something: leading item, title (or subtitle + status), value, ›.
    component SettingsLink: AbstractButton {
        id: row
        property string title
        property string subtitle
        property string status
        property color statusColor: Theme.textMuted
        property string value
        property bool first: false
        property bool accent: false
        property bool showTitle: true
        property alias leading: leadingSlot.data
        width: parent ? parent.width : 0
        implicitHeight: subtitle !== "" ? 64 : 52
        Accessible.name: title
        background: Rectangle {
            color: row.pressed ? Theme.subtle : "transparent"
            Rectangle { visible: !row.first; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.borderMuted }
        }
        contentItem: RowLayout {
            spacing: 12
            Item {
                id: leadingSlot
                Layout.leftMargin: 12
                visible: children.length > 0
                implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
                implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: leadingSlot.visible ? 0 : 14
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    visible: row.showTitle
                    text: row.title
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontLg + 1
                    font.weight: Font.Medium
                    color: row.accent ? Theme.accentText : Theme.textStrong
                }
                Text {
                    Layout.fillWidth: true
                    visible: row.subtitle !== ""
                    text: row.subtitle
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontMd
                    color: Theme.textStrong
                }
                Text {
                    visible: row.status !== ""
                    text: row.status
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: row.statusColor
                }
            }
            Text {
                visible: row.value !== ""
                text: row.value
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textMuted
            }
            Icon { Layout.rightMargin: 12; visible: !row.accent; name: "chevronRight"; size: 16; color: Theme.textMuted }
        }
    }
}
