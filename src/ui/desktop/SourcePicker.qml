pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Namespace / app picker: recent sources, then namespaces and their apps
// side by side. Typing narrows both columns; ↑ ↓ choose, → apps, Enter opens.
Popup {
    id: root

    property string query
    property int nsIndex: 0
    readonly property var rows: opened ? Session.sourceMatches(query) : []
    readonly property var currentNs: rows.length > 0 ? rows[Math.min(nsIndex, rows.length - 1)] : null

    function openFirstApp() {
        if (currentNs && currentNs.apps.length > 0) openSource(currentNs.name, currentNs.apps[0].name)
    }
    function openSource(ns, app) {
        Session.selectSource(ns, app)
        close()
    }

    width: 640
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onOpened: {
        query = ""
        nsIndex = Math.max(0, rows.findIndex(r => r.name === Session.namespaceName))
        searchField.forceActiveFocus()
    }
    onQueryChanged: nsIndex = 0

    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: ColumnLayout {
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Choose a log source")

        // Search + environment
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.leftMargin: 14
            spacing: 10
            Icon { name: "search"; color: Theme.accent }
            TextInput {
                id: searchField
                Layout.fillWidth: true
                text: root.query
                onTextEdited: root.query = text
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg
                color: Theme.textStrong
                selectionColor: Theme.accentStrong
                clip: true
                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Find a namespace or app")
                Keys.onDownPressed: root.nsIndex = Math.min(root.nsIndex + 1, root.rows.length - 1)
                Keys.onUpPressed: root.nsIndex = Math.max(root.nsIndex - 1, 0)
                Keys.onRightPressed: event => {
                    if (cursorPosition === text.length && appList.count > 0) appList.forceActiveFocus()
                    else event.accepted = false
                }
                Keys.onReturnPressed: root.openFirstApp()
                Keys.onEnterPressed: root.openFirstApp()

                Text {
                    anchors.fill: parent
                    visible: searchField.text === ""
                    text: qsTr("Namespace or app")
                    font: searchField.font
                    color: Theme.textMuted
                }
            }
            EnvironmentBadge {
                name: Session.environmentName
                tint: Session.environmentColor
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

        // Recent
        SectionLabel {
            Layout.leftMargin: 14
            Layout.topMargin: 10
            Layout.bottomMargin: 4
            visible: Session.recentSources.count > 0 && root.query === ""
            text: qsTr("Recent")
        }
        Column {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 8
            visible: Session.recentSources.count > 0 && root.query === ""
            Repeater {
                model: Session.recentSources
                delegate: ItemDelegate {
                    id: recent
                    required property int index
                    required property string environmentName
                    required property string environmentColor
                    required property string namespaceName
                    required property string app
                    width: parent.width
                    height: 34
                    Accessible.name: qsTr("%1 / %2 in %3").arg(recent.namespaceName).arg(recent.app).arg(recent.environmentName)
                    onClicked: { Session.selectRecentSource(recent.index); root.close() }
                    background: Rectangle { radius: Theme.radiusMd; color: recent.hovered ? Theme.subtle : "transparent" }
                    contentItem: RowLayout {
                        spacing: 10
                        Icon { name: "history"; size: 14; color: Theme.textMuted }
                        SourceText {
                            Layout.fillWidth: true
                            namespaceName: recent.namespaceName
                            app: recent.app
                        }
                        Text {
                            text: recent.environmentName
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.DemiBold
                            color: recent.environmentColor
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.borderMuted
            visible: Session.recentSources.count > 0 && root.query === ""
        }

        // Namespaces | apps
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            spacing: 0

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 4
                SectionLabel {
                    Layout.leftMargin: 14
                    Layout.topMargin: 10
                    text: qsTr("Namespace · %1").arg(root.rows.length)
                }
                ListView {
                    id: nsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    clip: true
                    model: root.rows
                    currentIndex: root.nsIndex
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: ItemDelegate {
                        id: ns
                        required property int index
                        required property var modelData
                        readonly property bool current: ns.index === root.nsIndex
                        width: ListView.view.width
                        height: 32
                        Accessible.name: qsTr("%1, %n app(s)", "", ns.modelData.appCount).arg(ns.modelData.name)
                        onClicked: root.nsIndex = ns.index
                        background: Rectangle {
                            radius: Theme.radiusMd
                            color: ns.current ? Theme.accentSoft : (ns.hovered ? Theme.subtle : "transparent")
                        }
                        contentItem: RowLayout {
                            spacing: 8
                            MatchText { Layout.fillWidth: true; match: ns.modelData; strong: ns.current }
                            Text {
                                text: ns.modelData.appCount
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontXs
                                color: Theme.textMuted
                            }
                            Icon { name: "chevronRight"; size: 12; color: Theme.textMuted }
                        }
                    }
                }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.borderMuted }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 4
                SectionLabel {
                    Layout.leftMargin: 14
                    Layout.topMargin: 10
                    text: root.currentNs ? qsTr("Apps in %1 · %2").arg(root.currentNs.name).arg(root.currentNs.apps.length) : ""
                }
                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    clip: true
                    model: root.currentNs ? root.currentNs.apps : []
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: true
                    Keys.onLeftPressed: searchField.forceActiveFocus()
                    Keys.onReturnPressed: root.openSource(root.currentNs.name, root.currentNs.apps[currentIndex].name)
                    Keys.onEnterPressed: root.openSource(root.currentNs.name, root.currentNs.apps[currentIndex].name)
                    delegate: ItemDelegate {
                        id: appItem
                        required property int index
                        required property var modelData
                        readonly property bool selected: root.currentNs !== null && root.currentNs.name === Session.namespaceName
                                                         && appItem.modelData.name === Session.app
                        readonly property bool keyed: appList.activeFocus && appList.currentIndex === appItem.index
                        width: ListView.view.width
                        height: 32
                        Accessible.name: appItem.modelData.name
                        onClicked: root.openSource(root.currentNs.name, appItem.modelData.name)
                        background: Rectangle {
                            radius: Theme.radiusMd
                            color: appItem.keyed || appItem.selected ? Theme.accentSoft : (appItem.hovered ? Theme.subtle : "transparent")
                        }
                        contentItem: RowLayout {
                            spacing: 8
                            MatchText { Layout.fillWidth: true; match: appItem.modelData; strong: appItem.selected || appItem.keyed }
                            Icon { visible: appItem.selected; name: "check"; size: 14; strokeWidth: 2.5; color: Theme.success }
                        }
                    }
                }
            }
        }

        // Footer: keys and the discovered labels
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            color: Theme.bg
            radius: Theme.radiusLg + 2
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 14
                Row { spacing: 4; Kbd { text: "↑" } Kbd { text: "↓" } HintText { text: qsTr("choose") } }
                Row { spacing: 4; Kbd { text: "→" } HintText { text: qsTr("apps") } }
                Row { spacing: 4; Kbd { text: "Enter" } HintText { text: qsTr("open") } }
                Item { Layout.fillWidth: true }
                HintText {
                    visible: Session.namespaceLabel !== ""
                    text: qsTr("Labels: %1 / %2 (found automatically)").arg(Session.namespaceLabel).arg(Session.appLabel)
                }
            }
        }
    }

    component HintText: Text {
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }

    // A name with the matched part underlined (rows from Session.sourceMatches):
    // three Texts, so each part keeps its own font and colour.
    component MatchText: Row {
        property var match
        property bool strong: false
        readonly property color baseColor: strong ? Theme.textStrong : Theme.text
        clip: true
        Text { text: parent.match ? parent.match.pre : ""; font.family: Theme.mono; font.pixelSize: Theme.fontMd; color: parent.baseColor }
        Text {
            text: parent.match ? parent.match.hit : ""
            font.family: Theme.mono
            font.pixelSize: Theme.fontMd
            font.underline: true
            color: Theme.textStrong
        }
        Text { text: parent.match ? parent.match.post : ""; font.family: Theme.mono; font.pixelSize: Theme.fontMd; color: parent.baseColor }
    }

    // "namespace / app" with a muted namespace.
    component SourceText: Row {
        property string namespaceName
        property string app
        spacing: 6
        clip: true
        Text { text: parent.namespaceName; font.family: Theme.mono; font.pixelSize: Theme.fontMd; color: Theme.textMuted }
        Text { text: "/"; font.family: Theme.mono; font.pixelSize: Theme.fontMd; color: Theme.border }
        Text { text: parent.app; font.family: Theme.mono; font.pixelSize: Theme.fontMd; color: Theme.textStrong }
    }
}
