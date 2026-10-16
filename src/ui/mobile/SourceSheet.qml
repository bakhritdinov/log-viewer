pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The log source, almost on the whole screen: environment, a search, recent
// sources and every namespace (one open at a time) with its apps. Typing
// turns it into a flat list (app large, namespace under it); tapping a source
// opens it and closes the sheet.
BottomSheet {
    id: root

    signal settingsRequested()
    signal addEnvironmentRequested()

    property string query
    property string openNamespace                 // the expanded one in the full list
    readonly property var rows: opened ? Session.sourceMatches(query) : []
    readonly property int matchCount: rows.reduce((n, r) => n + r.apps.length, 0)
    // "" the lists; "loading", "error" (nothing found yet) or "nomatch" (typed text).
    readonly property string state: Session.namespaces.length === 0
                                    ? (Session.discovering ? "loading" : Session.hasError ? "error" : "")
                                    : (query.trim() !== "" && matchCount === 0 ? "nomatch" : "")
    readonly property bool searching: query.trim() !== ""

    function openSource(ns, app) {
        Session.selectSource(ns, app)
        close()
    }

    tall: true
    title: qsTr("Log source")
    onAboutToShow: { query = ""; searchField.text = ""; openNamespace = Session.namespaceName }

    pinned: [
        // Environments (hidden while typing: the results stay above the keyboard).
        Flickable {
            Layout.fillWidth: true
            visible: !root.searching
            implicitHeight: 40
            contentWidth: envRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: envRow
                spacing: 8
                Repeater {
                    model: Session.environments
                    delegate: AbstractButton {
                        id: env
                        required property var model
                        readonly property bool current: model.current
                        implicitHeight: 40
                        implicitWidth: envLabel.implicitWidth + 44
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: model.name
                        Accessible.checked: current
                        onClicked: if (!current) Session.switchEnvironment(model.id)
                        background: Rectangle {
                            radius: 20
                            color: env.pressed ? Theme.hover : env.current ? Theme.tint(env.model.color, 0.14) : "transparent"
                            border.width: 1
                            border.color: env.current ? Theme.tint(env.model.color, 0.7) : Theme.border
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: env.model.color }
                                Text {
                                    id: envLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: env.model.name
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontMd
                                    font.weight: Font.DemiBold
                                    color: env.model.configured ? Theme.textStrong : Theme.textMuted
                                }
                            }
                        }
                    }
                }
                AbstractButton {
                    id: addEnv
                    implicitHeight: 40
                    implicitWidth: addRow.implicitWidth + 24
                    Accessible.name: qsTr("Add an environment")
                    onClicked: { root.close(); root.addEnvironmentRequested() }
                    background: Rectangle {
                        radius: 20
                        color: addEnv.pressed ? Theme.subtle : "transparent"
                        border.width: 1
                        border.color: Theme.border
                    }
                    contentItem: Item {
                        Row {
                            id: addRow
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "plus"; size: 14; color: Theme.textMuted }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Add")
                                font.family: Theme.sans
                                font.pixelSize: Theme.fontMd
                                font.weight: Font.Medium
                                color: Theme.textMuted
                            }
                        }
                    }
                }
            }
        },
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Theme.radiusLg
            color: Theme.inputBg
            border.width: 1
            border.color: searchField.activeFocus ? Theme.accent : Theme.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 2
                spacing: 8
                Icon { name: "search"; size: 18; color: Theme.textMuted }
                TextInput {
                    id: searchField
                    activeFocusOnTab: true
                    Layout.fillWidth: true
                    clip: true
                    font.family: Theme.sans
                    font.pixelSize: 16
                    color: Theme.textStrong
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    Accessible.role: Accessible.EditableText
                    Accessible.name: qsTr("Find a namespace or an app")
                    onTextEdited: root.query = text
                    // Enter opens the first match.
                    onAccepted: if (root.searching && root.matchCount > 0) {
                        const r = root.rows.find(r => r.apps.length > 0)
                        root.openSource(r.name, r.apps[0].name)
                    }
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchField.text === ""
                        text: qsTr("Find a namespace or an app")
                        font: searchField.font
                        color: Theme.textDisabled
                    }
                }
                IconButton {
                    visible: searchField.text !== ""
                    touch: true
                    iconName: "close"
                    label: qsTr("Clear")
                    onClicked: { searchField.text = ""; root.query = "" }
                }
            }
        }
    ]

    // ── the lists ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.bottomMargin: 16
        visible: root.state === ""
        spacing: 6

        // Recent sources.
        Caption { visible: !root.searching && Session.recentSources.count > 0; text: qsTr("Recent") }
        Repeater {
            model: root.searching ? null : Session.recentSources
            delegate: AbstractButton {
                id: recent
                required property int index
                required property string environmentId
                required property string environmentName
                required property string environmentColor
                required property string namespaceName
                required property string app
                readonly property bool current: environmentId === Session.environmentId
                                                && namespaceName === Session.namespaceName && app === Session.app
                Layout.fillWidth: true
                implicitHeight: 48
                Accessible.name: namespaceName + " / " + app
                onClicked: { Session.selectRecentSource(index); root.close() }
                background: Rectangle {
                    radius: Theme.radiusLg
                    color: recent.pressed ? Theme.subtle : recent.current ? Theme.accentSoft : Theme.bg
                    border.width: 1
                    border.color: recent.current ? Theme.accent : Theme.borderMuted
                }
                contentItem: RowLayout {
                    spacing: 8
                    Text {
                        Layout.leftMargin: 12
                        Layout.fillWidth: true
                        textFormat: Text.StyledText
                        text: "<font color=\"%1\">%2 /</font> %3".arg(Theme.textMuted).arg(recent.namespaceName).arg(recent.app)
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontLg
                        color: Theme.textStrong
                    }
                    Text {
                        // The right margin is the check's when it shows, its own otherwise.
                        Layout.rightMargin: recent.current ? 0 : 12
                        visible: recent.environmentId !== Session.environmentId
                        text: recent.environmentName
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.DemiBold
                        color: recent.environmentColor
                    }
                    Icon { Layout.rightMargin: 12; visible: recent.current; name: "check"; size: 16; color: Theme.accentText }
                }
            }
        }

        // Every namespace, one open at a time.
        Caption {
            Layout.topMargin: Session.recentSources.count > 0 ? 10 : 0
            visible: !root.searching
            text: qsTr("All · %1").arg(Session.environmentName)
        }
        ListFrame {
            visible: !root.searching
            Repeater {
                model: root.searching ? [] : root.rows
                delegate: Column {
                    id: ns
                    required property int index
                    required property var modelData
                    readonly property bool expanded: modelData.name === root.openNamespace
                    width: parent ? parent.width : 0
                    AbstractButton {
                        id: nsHeader
                        width: parent.width
                        height: 48
                        Accessible.role: Accessible.Button
                        Accessible.name: ns.modelData.name
                        Accessible.description: ns.expanded ? qsTr("expanded") : qsTr("collapsed")
                        onClicked: root.openNamespace = ns.expanded ? "" : ns.modelData.name
                        background: Rectangle {
                            color: nsHeader.pressed ? Theme.hover : Theme.subtle
                            Rectangle { visible: ns.index > 0; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
                        }
                        contentItem: RowLayout {
                            spacing: 10
                            Icon { Layout.leftMargin: 12; name: ns.expanded ? "chevronDown" : "chevronRight"; size: 14; color: Theme.textMuted }
                            Text {
                                Layout.fillWidth: true
                                text: ns.modelData.name
                                elide: Text.ElideRight
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontLg
                                font.weight: ns.expanded ? Font.DemiBold : Font.Normal
                                color: ns.expanded ? Theme.textStrong : Theme.text
                            }
                            Text {
                                Layout.rightMargin: 12
                                text: ns.modelData.appCount
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontSm
                                color: Theme.textMuted
                            }
                        }
                    }
                    Repeater {
                        model: ns.expanded ? ns.modelData.apps : []
                        delegate: AbstractButton {
                            id: appRow
                            required property var modelData
                            // ns is gone for a moment while the list changes.
                            readonly property string nsName: ns?.modelData?.name ?? ""
                            readonly property bool current: nsName === Session.namespaceName && modelData.name === Session.app
                            width: ns?.width ?? 0
                            height: 44
                            Accessible.name: nsName + " / " + modelData.name
                            onClicked: root.openSource(nsName, modelData.name)
                            background: Rectangle {
                                color: appRow.pressed ? Theme.hover : appRow.current ? Theme.accentSoft : Theme.surface
                                Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.borderMuted }
                            }
                            contentItem: RowLayout {
                                Text {
                                    Layout.leftMargin: 36
                                    Layout.fillWidth: true
                                    text: appRow.modelData.name
                                    elide: Text.ElideRight
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontLg
                                    color: appRow.current ? Theme.textStrong : Theme.text
                                }
                                Icon { Layout.rightMargin: 12; visible: appRow.current; name: "check"; size: 16; color: Theme.accentText }
                            }
                        }
                    }
                }
            }
        }

        // Typing: a flat list of the matching apps.
        Caption { visible: root.searching; text: qsTr("Found in %1 · %2").arg(Session.environmentName).arg(root.matchCount) }
        ListFrame {
            visible: root.searching
            Repeater {
                model: root.searching ? root.rows : []
                delegate: Column {
                    id: group
                    required property var modelData
                    width: parent ? parent.width : 0
                    Repeater {
                        model: group.modelData.apps
                        delegate: AbstractButton {
                            id: match
                            required property var modelData
                            readonly property var nsMatch: group?.modelData ?? null
                            width: group?.width ?? 0
                            height: 60
                            Accessible.name: (nsMatch ? nsMatch.name : "") + " / " + modelData.name
                            onClicked: root.openSource(nsMatch.name, modelData.name)
                            background: Rectangle {
                                color: match.pressed ? Theme.subtle : Theme.surface
                                Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.borderMuted }
                            }
                            contentItem: Column {
                                leftPadding: 12
                                topPadding: 10
                                spacing: 3
                                MatchText { match: match.modelData; size: Theme.fontLg + 1; strong: true }
                                MatchText { match: match.nsMatch; size: Theme.fontSm }
                            }
                        }
                    }
                }
            }
        }
    }

    // Nothing matches the typed text: maybe it is in another environment.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 16
        visible: root.state === "nomatch"
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: qsTr("No “%1” in %2").arg(root.query.trim()).arg(Session.environmentName)
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontXl
            font.weight: Font.DemiBold
            color: Theme.textStrong
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Check the spelling or search another environment.")
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontLg
            color: Theme.textMuted
        }
        Repeater {
            model: Session.environments
            delegate: AppButton {
                required property var model
                Layout.fillWidth: true
                visible: !model.current && model.configured
                touch: true
                text: qsTr("Search in %1").arg(model.name)
                onClicked: Session.switchEnvironment(model.id)      // the typed text stays
            }
        }
    }

    // Finding the namespaces after switching the environment.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 16
        visible: root.state === "loading"
        spacing: 14
        Text {
            text: qsTr("Finding namespaces in %1…").arg(Session.environmentName)
            font.family: Theme.sans
            font.pixelSize: Theme.fontLg
            color: Theme.textMuted
        }
        Repeater {
            model: [0.7, 0.55, 0.8, 0.6, 0.5]
            delegate: Rectangle {
                required property real modelData
                Layout.preferredWidth: (root.width - 32) * modelData
                implicitHeight: 14
                radius: Theme.radiusSm
                color: Theme.subtle
            }
        }
    }

    // Discovery failed: why, and the way on (unknown labels are a yellow card).
    Rectangle {
        id: failure
        readonly property bool labels: Session.error.kind === ErrorInfo.UnknownLabels
        Layout.fillWidth: true
        Layout.margins: 16
        visible: root.state === "error"
        implicitHeight: failureColumn.implicitHeight + 28
        radius: Theme.radiusLg
        color: labels ? Theme.warnSoft : Theme.dangerSoft
        border.width: 1
        border.color: labels ? Theme.tint(Theme.warn, 0.45) : Theme.dangerBorder
        ColumnLayout {
            id: failureColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10
            RowLayout {
                spacing: 8
                Icon { name: failure.labels ? "search" : "offline"; size: 18; color: failure.labels ? Theme.warn : Theme.danger }
                Text {
                    Layout.fillWidth: true
                    text: Session.error.title
                    wrapMode: Text.Wrap
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }
            Text {
                Layout.fillWidth: true
                text: Session.error.message
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg
                color: Theme.text
            }
            GridLayout {
                Layout.fillWidth: true
                columns: failure.labels ? 1 : 2
                columnSpacing: 8
                AppButton {
                    Layout.fillWidth: true
                    touch: true
                    variant: "primary"
                    text: failure.labels ? qsTr("Choose the labels") : qsTr("Retry")
                    onClicked: {
                        if (failure.labels) { root.close(); root.settingsRequested() }
                        else Session.rediscover()
                    }
                }
                AppButton {
                    Layout.fillWidth: true
                    visible: !failure.labels
                    touch: true
                    text: qsTr("Settings")
                    onClicked: { root.close(); root.settingsRequested() }
                }
            }
        }
    }

    component Caption: Text {
        Layout.fillWidth: true
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.7
        font.capitalization: Font.AllUppercase
        color: Theme.textMuted
        elide: Text.ElideRight
    }

    component ListFrame: Rectangle {
        default property alias rows: frameColumn.data
        Layout.fillWidth: true
        implicitHeight: frameColumn.implicitHeight + 2
        radius: Theme.radiusLg
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderMuted
        clip: true
        Column {
            id: frameColumn
            x: 1
            y: 1
            width: parent.width - 2
        }
    }

    // A name with the matched part underlined (rows from Session.sourceMatches).
    component MatchText: Row {
        property var match
        property bool strong: false
        property int size: Theme.fontLg
        readonly property color baseColor: strong ? Theme.textStrong : Theme.textMuted
        Text { text: parent.match ? parent.match.pre : ""; font.family: Theme.mono; font.pixelSize: parent.size; color: parent.baseColor }
        Text {
            text: parent.match ? parent.match.hit : ""
            font.family: Theme.mono
            font.pixelSize: parent.size
            font.underline: true
            color: Theme.textStrong
        }
        Text { text: parent.match ? parent.match.post : ""; font.family: Theme.mono; font.pixelSize: parent.size; color: parent.baseColor }
    }
}
