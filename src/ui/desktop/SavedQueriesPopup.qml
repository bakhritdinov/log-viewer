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
    function openBrowsing() {
        tab = 0
        open()
    }

    width: 520
    padding: 0
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onClosed: renamingId = ""

    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: ColumnLayout {
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Saved queries")

        SegmentedControl {
            Layout.margins: 12
            model: [{ label: qsTr("Saved"), value: 0 }, { label: qsTr("Recent searches"), value: 1 }]
            value: root.tab
            onActivated: v => root.tab = v
        }

        // ── Saved ──
        RowLayout {
            visible: root.tab === 0
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 8
            AppTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("Query name")
                Accessible.name: qsTr("Query name")
                onAccepted: saveButton.clicked()
            }
            AppButton {
                id: saveButton
                variant: "primary"
                iconName: "star"
                text: qsTr("Save current")
                enabled: nameField.text.trim() !== "" && Session.namespaceName !== ""
                onClicked: { Session.saveCurrentQuery(nameField.text.trim()); nameField.text = "" }
            }
        }
        ListView {
            id: savedList
            visible: root.tab === 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 320)
            Layout.margins: 6
            Layout.topMargin: 10
            clip: true
            model: Session.savedQueries
            boundsBehavior: Flickable.StopAtBounds
            delegate: ItemDelegate {
                id: query
                required property int index
                required property string id
                required property string name
                required property string summary
                required property string environmentName
                required property string environmentColor
                readonly property bool renaming: root.renamingId === query.id
                width: ListView.view.width
                height: 48
                Accessible.name: qsTr("%1: %2").arg(query.name).arg(query.summary)
                onClicked: if (!query.renaming) { Session.runSavedQuery(query.id); root.close() }
                background: Rectangle { radius: Theme.radiusMd; color: query.hovered ? Theme.subtle : "transparent" }
                contentItem: RowLayout {
                    spacing: 10
                    Text {
                        visible: query.index < 9
                        text: query.index + 1
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontXs
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
                        Layout.fillWidth: true
                        visible: query.renaming
                        text: query.name
                        Accessible.name: qsTr("New name")
                        onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                        onAccepted: { Session.renameSavedQuery(query.id, text.trim()); root.renamingId = "" }
                        Keys.onEscapePressed: root.renamingId = ""
                    }
                    Text {
                        text: query.environmentName
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.DemiBold
                        color: query.environmentColor
                    }
                    IconButton {
                        id: moreButton
                        iconName: "more"
                        label: qsTr("More actions with “%1”").arg(query.name)
                        onClicked: moreMenu.open()
                        Menu {
                            id: moreMenu
                            y: moreButton.height
                            MenuItem { text: qsTr("Rename"); onTriggered: root.renamingId = query.id }
                            MenuItem { text: qsTr("Delete"); onTriggered: Session.removeSavedQuery(query.id) }
                        }
                    }
                }
            }
        }
        Text {
            visible: root.tab === 0 && savedList.count === 0
            Layout.fillWidth: true
            Layout.margins: 16
            wrapMode: Text.Wrap
            text: qsTr("No saved queries yet. Name the current search and press “Save current”.")
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
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
                required property string modelData
                width: ListView.view.width
                height: 32
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
                        font.pixelSize: Theme.fontMd
                        color: Theme.text
                    }
                }
            }
        }
        Text {
            visible: root.tab === 1 && historyList.count === 0
            Layout.margins: 16
            text: qsTr("No recent searches.")
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }

        // Footer
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            color: Theme.bg
            radius: Theme.radiusLg + 2
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 6
                Kbd { visible: root.tab === 0; text: qsTr("Ctrl+1…9") }
                Text {
                    Layout.fillWidth: true
                    text: root.tab === 0 ? qsTr("run by number · stored on this device") : ""
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
                AppButton {
                    visible: root.tab === 1 && historyList.count > 0
                    variant: "ghost"
                    text: qsTr("Clear history")
                    onClicked: Session.clearHistory()
                }
            }
        }
    }
}
