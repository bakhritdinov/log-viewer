import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Saves the current search under a name (offered and selected), or renames a
// saved query (`renameId`). A name already taken: a yellow note, and the
// button replaces that query instead.
BottomSheet {
    id: root

    signal notice(string text, string actionText, var action)

    property string renameId                 // "" saves the current search
    readonly property bool renaming: renameId !== ""

    function openSaving() { renameId = ""; open() }
    function openRenaming(id) { renameId = id; open() }

    function rowOf(id) {
        for (let i = 0; i < Session.savedQueries.count; ++i)
            if (Session.savedQueries.get(i).id === id) return i
        return -1
    }
    readonly property var renamed: renaming && opened ? Session.savedQueries.get(rowOf(renameId)) : null
    readonly property string conflictId: {
        const name = nameField.text.trim()
        const id = opened && name !== "" ? Session.savedQueryIdByName(name) : ""
        return id === renameId ? "" : id
    }
    readonly property int conflictNumber: conflictId !== "" ? rowOf(conflictId) + 1 : 0

    function accept() {
        const name = nameField.text.trim()
        if (name === "") return
        if (renaming) {
            if (conflictId !== "") return
            Session.renameSavedQuery(renameId, name)
        } else if (conflictId !== "") {
            Session.replaceSavedQuery(conflictId)
            notice(qsTr("Query “%1” now holds the current search").arg(name), "", null)
        } else {
            if (Session.namespaceName === "") return
            Session.saveCurrentQuery(name)
            notice(qsTr("Query “%1” saved").arg(name), "", null)
        }
        close()
    }

    title: renaming ? qsTr("Rename the query") : qsTr("Save the query")
    onOpened: {
        nameField.text = renaming && renamed ? renamed.name : Session.suggestedQueryName()
        nameField.forceActiveFocus()
        nameField.selectAll()
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: {
                if (root.renaming) return root.renamed ? root.renamed.summary : ""
                const search = Session.searchText.trim() === "" ? qsTr("all entries") : Session.searchText
                return [Session.app, search, Session.timeRangeShortLabel, Session.environmentName].join(" · ")
            }
            elide: Text.ElideRight
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
        AppTextField {
            id: nameField
            Layout.fillWidth: true
            touch: true
            font.pixelSize: 16                   // no zoom on focus in iOS Safari
            Accessible.name: qsTr("Query name")
            onAccepted: root.accept()
        }
        Text {
            Layout.fillWidth: true
            visible: root.conflictId !== ""
            text: root.renaming ? qsTr("Query № %1 already has this name").arg(root.conflictNumber)
                                : qsTr("Replaces query № %1").arg(root.conflictNumber)
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.warnText
        }
    }

    footer: AppButton {
        Layout.fillWidth: true
        touch: true
        variant: "primary"
        text: root.renaming ? qsTr("Rename") : root.conflictId !== "" ? qsTr("Replace") : qsTr("Save")
        enabled: nameField.text.trim() !== "" && !(root.renaming && root.conflictId !== "")
        onClicked: root.accept()
    }
}
