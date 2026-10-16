pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Saved queries (stored on this device) and recent searches.
// Ctrl+1…Ctrl+9 run the saved queries by position.
Popup {
    id: root

    property int tab: 0                 // 0 saved, 1 history
    property string renamingId

    function openSaving() {
        tab = 0
        open()
        nameField.text = Session.suggestedQueryName()
        nameField.forceActiveFocus()
        nameField.selectAll()
    }
    // The history button: straight to the recent searches (the star saves).
    function openRecent() {
        tab = 1
        open()
    }
    // Notices go to the window's toast (with an optional action).
    function notify(text, actionText, action) {
        const w = body.ApplicationWindow.window
        if (w && w.notify) w.notify(text, actionText, action)   // qmllint disable missing-property
    }

    // A saved query with the typed name: saving replaces it.
    readonly property string conflictId: opened && nameField.text.trim() !== "" ? Session.savedQueryIdByName(nameField.text) : ""
    readonly property int conflictNumber: {
        if (conflictId === "") return 0
        for (let i = 0; i < Session.savedQueries.count; ++i)
            if (Session.savedQueries.get(i).id === conflictId) return i + 1
        return 0
    }

    // The saved query takes the current source, search and period; its row
    // flashes so the change is visible even when the summary barely differs.
    property string flashedId
    function replaceWithCurrent(id, name) {
        Session.replaceSavedQuery(id)
        flashedId = id
        flashTimer.restart()
        notify(qsTr("Query “%1” now holds the current search").arg(name))
    }
    Timer { id: flashTimer; interval: 1200; onTriggered: root.flashedId = "" }

    function save() {
        const name = nameField.text.trim()
        if (name === "" || Session.namespaceName === "") return
        if (conflictId !== "") {
            replaceWithCurrent(conflictId, name)
            nameField.text = ""
            return
        }
        Session.saveCurrentQuery(name)
        const number = Session.savedQueries.count
        flashedId = Session.savedQueries.get(number - 1).id
        flashTimer.restart()
        nameField.text = ""
        notify(number <= 9 ? qsTr("Query “%1” saved · Ctrl+%2").arg(name).arg(number) : qsTr("Query “%1” saved").arg(name))
    }

    width: 520
    padding: 0
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onClosed: renamingId = ""

    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    Clipboard { id: clipboard }

    contentItem: ColumnLayout {
        id: body
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Saved queries")

        SegmentedControl {
            Layout.margins: 12
            Layout.bottomMargin: 0
            model: [{ label: qsTr("Saved"), value: 0 }, { label: qsTr("Recent searches"), value: 1 }]
            value: root.tab
            onActivated: v => root.tab = v
        }

        // ── Saved ──
        ColumnLayout {
            visible: root.tab === 0
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                AppTextField {
                    id: nameField
                    Layout.fillWidth: true
                    implicitHeight: 34
                    placeholderText: qsTr("Name of the current query")
                    Accessible.name: qsTr("Query name")
                    onAccepted: root.save()
                    Keys.onEscapePressed: event => { if (text !== "") { text = ""; event.accepted = true } else event.accepted = false }
                    background: Rectangle {
                        radius: Theme.radiusMd
                        color: Theme.inputBg
                        border.width: 1
                        border.color: root.conflictId !== "" ? Theme.warn : nameField.activeFocus ? Theme.focusRing : Theme.border
                    }
                }
                AppButton {
                    variant: "primary"
                    implicitHeight: 34
                    iconName: "star"
                    text: root.conflictId !== "" ? qsTr("Replace") : qsTr("Save")
                    enabled: nameField.text.trim() !== "" && Session.namespaceName !== ""
                    onClicked: root.save()
                }
            }
            RowLayout {
                visible: root.conflictId !== ""
                spacing: 6
                Icon { name: "warning"; size: 13; color: Theme.warnText }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("Query “%1” already exists (No. %2). Saving replaces it.").arg(nameField.text.trim()).arg(root.conflictNumber)
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.warnText
                }
            }
        }

        ListView {
            id: savedList
            visible: root.tab === 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 336)
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 6
            clip: true
            model: Session.savedQueries
            boundsBehavior: Flickable.StopAtBounds
            delegate: ItemDelegate {
                id: query
                // Basic's 12 px vertical padding pushes the content below the row's centre.
                topPadding: 0
                bottomPadding: 0
                leftPadding: 10
                rightPadding: 8
                hoverEnabled: true
                required property int index
                required property string id
                required property string name
                required property string summary
                required property string environmentName
                required property string environmentColor
                readonly property bool renaming: root.renamingId === query.id
                readonly property bool actionsShown: hovered || moreMenu.opened || query.visualFocus
                width: ListView.view.width
                height: 48
                Accessible.name: qsTr("%1: %2").arg(query.name).arg(query.summary)
                onClicked: if (!query.renaming) { Session.runSavedQuery(query.id); root.close() }
                background: Rectangle {
                    radius: Theme.radiusLg - 2
                    color: root.flashedId === query.id ? Theme.successSoft
                         : query.renaming || query.actionsShown ? Theme.subtle : "transparent"
                    Behavior on color { ColorAnimation { duration: 250 } }
                    border.width: query.renaming || query.visualFocus ? 1 : 0
                    border.color: Theme.focusRing
                }
                contentItem: RowLayout {
                    spacing: 10
                    Text {
                        Layout.preferredWidth: 14
                        text: query.index < 9 ? query.index + 1 : ""
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: Theme.textMuted
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        visible: !query.renaming
                        Text {
                            Layout.fillWidth: true
                            text: query.name
                            elide: Text.ElideRight
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                            color: Theme.textStrong
                        }
                        Text {
                            Layout.fillWidth: true
                            text: query.summary
                            elide: Text.ElideRight
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            color: Theme.textMuted
                        }
                    }
                    AppTextField {
                        id: renameField
                        Layout.fillWidth: true
                        implicitHeight: 32
                        visible: query.renaming
                        text: query.name
                        Accessible.name: qsTr("New name")
                        onVisibleChanged: if (visible) { text = query.name; forceActiveFocus(); selectAll() }
                        onAccepted: if (text.trim() !== "") { Session.renameSavedQuery(query.id, text.trim()); root.renamingId = "" }
                        Keys.onEscapePressed: root.renamingId = ""
                    }
                    IconButton {
                        visible: query.renaming
                        iconName: "check"
                        iconColor: Theme.success
                        label: qsTr("Save the name")
                        onClicked: if (renameField.text.trim() !== "") { Session.renameSavedQuery(query.id, renameField.text.trim()); root.renamingId = "" }
                    }
                    IconButton {
                        visible: query.renaming
                        iconName: "close"
                        label: qsTr("Cancel")
                        onClicked: root.renamingId = ""
                    }
                    Text {
                        visible: !query.renaming
                        text: query.environmentName
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.DemiBold
                        color: query.environmentColor
                    }
                    // Shown on the hovered row; the place stays reserved so nothing jumps.
                    IconButton {
                        visible: !query.renaming
                        opacity: query.actionsShown ? 1 : 0
                        implicitWidth: 28
                        implicitHeight: 28
                        iconName: "link"
                        label: qsTr("Copy the link to “%1”").arg(query.name)
                        onClicked: { clipboard.copy(Session.savedQueryLink(query.id)); root.notify(qsTr("Link copied")) }
                    }
                    IconButton {
                        id: moreButton
                        visible: !query.renaming
                        opacity: query.actionsShown ? 1 : 0
                        implicitWidth: 28
                        implicitHeight: 28
                        iconName: "more"
                        checked: moreMenu.opened
                        label: qsTr("More actions with “%1”").arg(query.name)
                        onClicked: moreMenu.toggle()
                        AppMenu {
                            id: moreMenu
                            y: moreButton.height + 4
                            x: moreButton.width - width
                            minimumWidth: 230
                            AppMenuItem { iconName: "pencil"; text: qsTr("Rename"); onTriggered: root.renamingId = query.id }
                            AppMenuItem {
                                iconName: "refresh"
                                text: qsTr("Replace with the current query")
                                enabled: Session.namespaceName !== ""
                                onTriggered: root.replaceWithCurrent(query.id, query.name)
                            }
                            AppMenuItem {
                                iconName: "chevronUp"
                                text: qsTr("Move up")
                                enabled: query.index > 0
                                onTriggered: Session.moveSavedQueryUp(query.id)
                            }
                            AppMenuSeparator { }
                            AppMenuItem {
                                iconName: "trash"
                                text: qsTr("Delete")
                                danger: true
                                onTriggered: {
                                    const name = query.name
                                    Session.removeSavedQuery(query.id)
                                    root.notify(qsTr("Query “%1” deleted").arg(name), qsTr("Undo"), () => Session.restoreSavedQuery())
                                }
                            }
                        }
                    }
                }
            }
        }
        ColumnLayout {
            visible: root.tab === 0 && savedList.count === 0
            Layout.fillWidth: true
            Layout.margins: 24
            Layout.topMargin: 12
            spacing: 8
            Icon { Layout.alignment: Qt.AlignHCenter; name: "star"; size: 28; strokeWidth: 1.6; color: Theme.textMuted }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No saved queries yet")
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                font.weight: Font.Medium
                color: Theme.textStrong
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Name the current search and press “Save”. The first nine run with Ctrl+1…Ctrl+9.")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }

        // ── History ──
        ListView {
            id: historyList
            visible: root.tab === 1
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
            Layout.margins: 6
            clip: true
            model: Session.history
            boundsBehavior: Flickable.StopAtBounds
            delegate: ItemDelegate {
                id: item
                // Basic's 12 px vertical padding pushes the content below the row's centre.
                topPadding: 0
                bottomPadding: 0
                hoverEnabled: true
                required property string modelData
                width: ListView.view.width
                height: 32
                leftPadding: 10
                rightPadding: 10
                Accessible.name: item.modelData
                onClicked: { Session.searchText = item.modelData; Session.search(); root.close() }
                background: Rectangle { radius: Theme.radiusMd; color: item.hovered ? Theme.subtle : "transparent" }
                contentItem: RowLayout {
                    spacing: 10
                    Icon { name: "history"; size: 14; color: Theme.textMuted }
                    Text {
                        Layout.fillWidth: true
                        text: item.modelData
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: Theme.text
                    }
                    // Where it was run.
                    Text {
                        readonly property string source: Session.historySource(item.modelData)
                        visible: source !== ""
                        Layout.maximumWidth: 160
                        text: source
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontXs
                        color: Theme.textMuted
                    }
                }
            }
        }
        Text {
            visible: root.tab === 1 && historyList.count === 0
            Layout.fillWidth: true
            Layout.margins: 16
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No recent searches.")
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }

        // Footer
        Rectangle {
            Layout.fillWidth: true
            // Inside the popup's border, rounded only at the popup's own corners.
            Layout.leftMargin: 1
            Layout.rightMargin: 1
            Layout.bottomMargin: 1
            implicitHeight: 38
            color: Theme.bg
            bottomLeftRadius: Theme.radiusLg + 1
            bottomRightRadius: Theme.radiusLg + 1
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 6
                Kbd { visible: root.tab === 0; text: qsTr("Ctrl+1…9") }
                Text {
                    Layout.fillWidth: true
                    text: root.tab === 0 ? qsTr("run by number · stored on this device") : qsTr("Last 50 searches")
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
                AppButton {
                    visible: root.tab === 1 && historyList.count > 0
                    variant: "ghost"
                    implicitHeight: 28
                    text: qsTr("Clear history")
                    onClicked: Session.clearHistory()
                }
            }
        }
    }
}
