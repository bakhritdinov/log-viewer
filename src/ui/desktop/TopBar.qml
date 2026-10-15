pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Context on the left (environment, source, period), global actions on the right.
// The set of controls follows the mode: first run, search (loading or not),
// live tail, focus. The bar is always 52 px; narrow windows shorten labels.
Rectangle {
    id: root

    signal settingsRequested()
    signal labelsRequested()
    signal themeToggled()

    // Shortcut texts for tooltips (from the registered shortcuts).
    property string sourceKey
    property string timeKey
    property string refreshKey
    property string shareKey
    property string settingsKey

    function openSourcePicker() { if (sourceButton.visible) sourcePicker.open() }
    function openTimePicker() { if (timeButton.visible) timePopup.open() }
    function openShare() { if (shareArea.visible) sharePopup.open() }

    readonly property bool firstRun: Session.environments.count === 0
    readonly property bool focusMode: Session.focus.active
    readonly property bool live: Session.live.running && !focusMode
    readonly property bool searchMode: !firstRun && !focusMode && !live
    readonly property bool noSource: Session.namespaceName === ""
    readonly property bool loading: Session.loading && searchMode

    // Narrow windows: the order in which labels give way (see the design sheet).
    readonly property bool showLogoText: width >= 1280 || firstRun
    readonly property bool shareIconOnly: width < 1180
    readonly property bool shortPeriod: width < 1080

    readonly property var refreshOptions: [
        { seconds: 0, label: qsTr("Off") },
        { seconds: 5, label: qsTr("5 s") },
        { seconds: 10, label: qsTr("10 s") },
        { seconds: 30, label: qsTr("30 s") },
        { seconds: 60, label: qsTr("1 min") },
    ]

    implicitHeight: 52
    color: Theme.surface

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        Row {
            Layout.rightMargin: 6
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "logs"; size: 20; color: Theme.accent }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showLogoText
                text: "LogViewer"
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }
        }

        Text {
            visible: root.firstRun
            text: qsTr("Connect Grafana to start")
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }

        // Environment: a menu in search and live, a plain badge in focus mode.
        Button {
            id: envButton
            implicitHeight: Theme.controlHeight
            leftPadding: 10
            rightPadding: 10
            visible: !root.firstRun && !root.focusMode
            Accessible.name: qsTr("Environment: %1").arg(Session.environmentName)
            onClicked: envMenu.open()
            contentItem: Row {
                spacing: 8
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Session.environmentColor }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Session.environmentName
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevronDown"; size: 12; color: Theme.textMuted
                    rotation: envMenu.opened ? 180 : 0
                }
            }
            background: Rectangle {
                radius: Theme.radiusMd
                color: Theme.tint(Session.environmentColor, envButton.hovered || envMenu.opened ? 0.22 : 0.14)
                border.width: envButton.visualFocus ? 2 : 1
                border.color: envButton.visualFocus ? Theme.focusRing
                            : Theme.tint(Session.environmentColor, envButton.hovered || envMenu.opened ? 0.8 : 0.6)
            }

            AppMenu {
                id: envMenu
                y: envButton.height + 4
                Repeater {
                    model: Session.environments
                    delegate: AppMenuItem {
                        required property string id
                        required property string name
                        required property string color
                        required property string host
                        required property bool current
                        text: name
                        dotColor: color
                        checkedMark: current
                        hint: current ? "" : host
                        onTriggered: Session.switchEnvironment(id)
                    }
                }
                AppMenuSeparator { }
                AppMenuItem {
                    text: qsTr("Manage environments…")
                    hint: root.settingsKey
                    onTriggered: root.settingsRequested()
                }
            }
        }
        EnvironmentBadge {
            visible: root.focusMode
            implicitHeight: Theme.controlHeight
            name: Session.environmentName
            tint: Session.environmentColor
        }

        // Source: highlighted while nothing is chosen.
        Button {
            id: sourceButton
            visible: !root.firstRun && !root.focusMode
            implicitHeight: Theme.controlHeight
            Layout.preferredWidth: root.shortPeriod ? 200 : Math.max(260, implicitWidth)
            Layout.maximumWidth: root.shortPeriod ? 200 : 420
            leftPadding: 12
            rightPadding: 10
            Accessible.name: root.noSource ? qsTr("Choose a source")
                                           : qsTr("Source: %1 / %2").arg(Session.namespaceName).arg(Session.app)
            onClicked: sourcePicker.open()

            AppToolTip {
                visible: sourceButton.hovered && !sourcePicker.opened
                text: root.noSource ? qsTr("Choose a source")
                                    : qsTr("%1 / %2 — change the source").arg(Session.namespaceName).arg(Session.app)
                shortcut: root.sourceKey
            }

            contentItem: RowLayout {
                spacing: 8
                Icon { name: "source"; size: 14; color: root.noSource ? Theme.accent : Theme.textMuted }
                Text {
                    Layout.fillWidth: true
                    visible: root.noSource
                    text: qsTr("Choose a source")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Medium
                    color: Theme.textStrong
                    elide: Text.ElideRight
                }
                Kbd { visible: root.noSource && root.sourceKey !== ""; text: root.sourceKey }
                Text {
                    Layout.fillWidth: true
                    visible: !root.noSource
                    textFormat: Text.StyledText
                    text: "<font color=\"%1\">%2</font> <font color=\"%3\">/</font> %4"
                          .arg(Theme.textMuted).arg(Session.namespaceName).arg(Theme.border).arg(Session.app)
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    color: Theme.textStrong
                    elide: Text.ElideMiddle
                }
                Icon {
                    name: "chevronDown"; size: 12
                    color: root.noSource ? Theme.accent : Theme.textMuted
                    rotation: sourcePicker.opened ? 180 : 0
                }
            }
            background: Rectangle {
                radius: Theme.radiusMd
                color: root.noSource ? Theme.accentSoft
                     : (sourceButton.hovered || sourcePicker.opened ? Theme.hover : Theme.subtle)
                border.width: sourceButton.visualFocus ? 2 : 1
                border.color: sourceButton.visualFocus || root.noSource ? Theme.focusRing
                            : (sourceButton.hovered || sourcePicker.opened ? Theme.hoverBorder : Theme.border)
            }

            SourcePicker {
                id: sourcePicker
                y: sourceButton.height + 4
                onSettingsRequested: root.settingsRequested()
                onLabelsRequested: root.labelsRequested()
            }
        }
        Text {
            visible: root.focusMode
            textFormat: Text.StyledText
            text: "<font color=\"%1\">%2 /</font> %3".arg(Theme.textMuted).arg(Session.namespaceName).arg(Session.app)
            font.family: Theme.mono
            font.pixelSize: Theme.fontMd
            color: Theme.textStrong
        }

        // Period
        AppButton {
            id: timeButton
            visible: root.searchMode
            iconName: "clock"
            text: root.shortPeriod ? Session.timeRangeShortLabel : Session.timeRangeLabel
            tooltip: timePopup.opened ? "" : qsTr("%1 – %2").arg(Session.absoluteFromText).arg(Session.absoluteToText)
            shortcut: root.timeKey
            onClicked: timePopup.open()

            TimeRangePopup {
                id: timePopup
                y: timeButton.height + 4
            }
        }
        Text {
            visible: root.live
            text: qsTr("No period needed — new entries are shown")
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
            elide: Text.ElideRight
            Layout.maximumWidth: 360
        }

        Item { Layout.fillWidth: true }

        // Refresh, then the auto-refresh menu beside it. While loading, the first one stops.
        Row {
            visible: root.searchMode
            spacing: 6
            AppButton {
                id: refreshButton
                visible: !root.loading
                variant: "primary"
                iconName: "refresh"
                text: qsTr("Refresh")
                enabled: !Session.needsSetup && !root.noSource
                tooltip: qsTr("Refresh")
                shortcut: root.refreshKey
                onClicked: Session.search()
            }
            AppButton {
                id: stopButton
                visible: root.loading
                Accessible.name: qsTr("Stop loading")
                onClicked: Session.stopLoading()
                contentItem: Row {
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "refresh"
                        size: 14
                        color: Theme.accent
                        RotationAnimator on rotation {
                            running: stopButton.visible
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Stop")
                        font: stopButton.font
                        color: Theme.textStrong
                    }
                    Kbd { anchors.verticalCenter: parent.verticalCenter; text: "Esc" }
                }
            }
            AppButton {
                id: autoButton
                variant: root.loading ? "secondary" : "primary"
                leftPadding: 8
                rightPadding: 8
                enabled: !Session.needsSetup && !root.noSource
                Accessible.name: Session.autoRefreshSeconds > 0
                                 ? qsTr("Auto refresh: every %1").arg(autoButton.currentLabel)
                                 : qsTr("Auto refresh: off")
                readonly property string currentLabel: {
                    for (const o of root.refreshOptions)
                        if (o.seconds === Session.autoRefreshSeconds) return o.label
                    return qsTr("%1 s").arg(Session.autoRefreshSeconds)
                }
                onClicked: refreshMenu.open()
                contentItem: Row {
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Session.autoRefreshSeconds > 0
                        width: 6; height: 6; radius: 3
                        color: Theme.successText
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Session.autoRefreshSeconds > 0
                        text: autoButton.currentLabel
                        font: autoButton.font
                        color: autoButton._fg
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevronDown"; size: 12
                        color: autoButton._fg
                        rotation: refreshMenu.opened ? 180 : 0
                    }
                }

                AppMenu {
                    id: refreshMenu
                    y: autoButton.height + 4
                    x: autoButton.width - width
                    Repeater {
                        model: root.refreshOptions
                        delegate: AppMenuItem {
                            required property var modelData
                            text: modelData.seconds === 0 ? qsTr("Auto refresh off")
                                : modelData.seconds === 60 ? qsTr("Every minute")
                                : qsTr("Every %1").arg(modelData.label)
                            // A fixed period does not change: nothing to refresh.
                            enabled: modelData.seconds === 0 || !Session.timeRangeAbsolute
                            checkedMark: Session.autoRefreshSeconds === modelData.seconds
                            onTriggered: Session.autoRefreshSeconds = modelData.seconds
                        }
                    }
                    Text {
                        visible: Session.timeRangeAbsolute
                        Layout.maximumWidth: 240
                        Layout.leftMargin: 32
                        Layout.rightMargin: 12
                        wrapMode: Text.Wrap
                        text: qsTr("A fixed period needs no auto refresh")
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }
                    AppMenuSeparator { }
                    AppMenuItem {
                        text: qsTr("Live tail")
                        dotColor: Theme.danger
                        hint: "LIVE"
                        hintDanger: true
                        onTriggered: Session.live.start()
                    }
                }
            }
        }

        // Live: one group — state and rate, pause/resume, leave.
        Rectangle {
            id: liveGroup
            visible: root.live
            readonly property bool paused: Session.live.paused
            implicitWidth: liveRow.implicitWidth + 2
            implicitHeight: Theme.controlHeight
            radius: Theme.radiusMd
            color: "transparent"
            border.width: 1
            border.color: paused ? Theme.warn : Theme.danger

            Row {
                id: liveRow
                anchors.centerIn: parent
                height: parent.height - 2

                Rectangle {
                    height: parent.height
                    width: liveState.implicitWidth + 24
                    // The end segments follow the group's rounded border.
                    topLeftRadius: liveGroup.radius - 1
                    bottomLeftRadius: liveGroup.radius - 1
                    color: liveGroup.paused ? Theme.warnSoft : Theme.dangerSoft
                    Row {
                        id: liveState
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !liveGroup.paused
                            width: 8; height: 8; radius: 4
                            color: Theme.danger
                            SequentialAnimation on opacity {
                                running: root.live && !liveGroup.paused
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { from: 1; to: 0.35; duration: 600 }
                                NumberAnimation { from: 0.35; to: 1; duration: 600 }
                            }
                        }
                        Icon { anchors.verticalCenter: parent.verticalCenter; visible: liveGroup.paused; name: "pause"; size: 10; strokeWidth: 3; color: Theme.warnText }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: liveGroup.paused
                                  ? (Session.live.pending > 0 ? qsTr("PAUSED · %n new", "", Session.live.pending) : qsTr("PAUSED"))
                                  : qsTr("LIVE · ~%1 lines/s").arg(Session.live.ratePerSecond.toLocaleString(Qt.locale(), "f", 0))
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.DemiBold
                            color: liveGroup.paused ? Theme.warnText : Theme.textStrong
                        }
                    }
                }
                Rectangle { width: 1; height: parent.height; color: liveGroup.paused ? Theme.warn : Theme.danger }
                AppButton {
                    id: pauseButton
                    height: parent.height
                    background.visible: false
                    variant: liveGroup.paused ? "primary" : "secondary"
                    iconName: liveGroup.paused ? "play" : "pause"
                    text: liveGroup.paused ? qsTr("Resume") : qsTr("Pause")
                    tooltip: qsTr("Pause / resume")
                    shortcut: qsTr("Space")
                    onClicked: Session.live.paused = !Session.live.paused
                    Rectangle {
                        z: -1
                        anchors.fill: parent
                        color: liveGroup.paused ? (pauseButton.hovered ? Theme.successBorder : Theme.successStrong)
                                                : (pauseButton.hovered ? Theme.hover : Theme.subtle)
                    }
                }
                Rectangle { width: 1; height: parent.height; color: Theme.border }
                IconButton {
                    id: leaveLive
                    height: parent.height
                    implicitWidth: 34
                    iconName: "close"
                    label: qsTr("Leave live")
                    onClicked: Session.live.stop()
                    background: Rectangle {
                        topRightRadius: liveGroup.radius - 1
                        bottomRightRadius: liveGroup.radius - 1
                        color: leaveLive.hovered ? Theme.hover : Theme.subtle
                    }
                }
            }
        }

        // Share: a text button, an icon on narrow windows.
        Item {
            id: shareArea
            visible: root.searchMode
            implicitWidth: root.shareIconOnly ? shareIcon.implicitWidth : shareButton.implicitWidth
            implicitHeight: Theme.controlHeight

            AppButton {
                id: shareButton
                visible: !root.shareIconOnly
                iconName: "link"
                text: qsTr("Share", "button: share a link")
                enabled: !root.noSource
                tooltip: sharePopup.opened ? "" : qsTr("Link to the current selection")
                shortcut: root.shareKey
                onClicked: sharePopup.open()
            }
            IconButton {
                id: shareIcon
                visible: root.shareIconOnly
                iconName: "link"
                label: qsTr("Link to the current selection")
                shortcut: root.shareKey
                enabled: !root.noSource
                onClicked: sharePopup.open()
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: shareIcon.hovered ? Theme.hover : Theme.subtle
                    border.width: 1
                    border.color: shareIcon.hovered ? Theme.hoverBorder : Theme.border
                }
            }
            SharePopup {
                id: sharePopup
                y: shareArea.height + 4
                x: shareArea.width - width
            }
        }
        IconButton {
            iconName: Theme.dark ? "moon" : "sun"
            label: Theme.dark ? qsTr("Light theme") : qsTr("Dark theme")
            onClicked: root.themeToggled()
        }
        IconButton {
            iconName: "settings"
            label: qsTr("Settings")
            shortcut: root.settingsKey
            checked: root.firstRun            // the first step: points at itself
            onClicked: root.settingsRequested()
        }
    }
}
