pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// What to do with one saved query ("…" on its row). Deleting is immediate,
// with "Undo" in the snackbar.
BottomSheet {
    id: root

    signal notice(string text, string actionText, var action)
    signal ran()
    signal renameRequested(string id)

    property string queryId
    function openFor(id) { queryId = id; open() }

    readonly property int row: {
        void Session.savedQueries.count
        for (let i = 0; i < Session.savedQueries.count; ++i)
            if (Session.savedQueries.get(i).id === queryId) return i
        return -1
    }
    readonly property var query: opened && row >= 0 ? Session.savedQueries.get(row) : null

    title: query ? query.name : ""

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.bottomMargin: 8
        text: root.query ? root.query.summary + (root.query.environmentName !== "" ? " · " + root.query.environmentName : "") : ""
        wrapMode: Text.Wrap
        font.family: Theme.mono
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }

    ActionRow { text: qsTr("Run"); iconName: "play"; onTriggered: { Session.runSavedQuery(root.queryId); root.close(); root.ran() } }
    ActionRow {
        text: qsTr("Share the link"); iconName: "link"
        onTriggered: {
            const link = Session.savedQueryLink(root.queryId)
            const name = root.query.name
            root.close()
            if (Session.device.canShare) Session.device.share(name, link)
            else { clipboard.copy(link); root.notice(qsTr("Link copied"), "", null) }
        }
    }
    ActionRow { text: qsTr("Rename"); iconName: "pencil"; onTriggered: { root.close(); root.renameRequested(root.queryId) } }
    ActionRow {
        text: qsTr("Replace with the current search"); iconName: "refresh"
        enabled: Session.namespaceName !== ""
        onTriggered: {
            const name = root.query.name
            Session.replaceSavedQuery(root.queryId)
            root.close()
            root.notice(qsTr("Query “%1” now holds the current search").arg(name), "", null)
        }
    }
    ActionRow {
        text: qsTr("Move up"); iconName: "arrowUp"
        enabled: root.row > 0
        onTriggered: Session.moveSavedQueryUp(root.queryId)
    }
    ActionRow {
        text: qsTr("Delete"); iconName: "trash"; danger: true
        onTriggered: {
            const name = root.query.name
            Session.removeSavedQuery(root.queryId)
            root.close()
            root.notice(qsTr("Query “%1” deleted").arg(name), qsTr("Undo"), () => Session.restoreSavedQuery())
        }
    }
    Item { implicitHeight: 12 }

    Clipboard { id: clipboard }

    component ActionRow: AbstractButton {
        id: action
        property string iconName
        property bool danger: false
        signal triggered()
        Layout.fillWidth: true
        implicitHeight: 48
        Accessible.name: text
        onClicked: triggered()
        background: Rectangle { color: action.pressed ? Theme.subtle : "transparent" }
        contentItem: RowLayout {
            spacing: 14
            Icon {
                Layout.leftMargin: 18
                name: action.iconName
                size: 18
                color: !action.enabled ? Theme.textDisabled : action.danger ? Theme.dangerText : Theme.textMuted
            }
            Text {
                Layout.fillWidth: true
                text: action.text
                font.family: Theme.sans
                font.pixelSize: Theme.fontLg + 1
                color: !action.enabled ? Theme.textDisabled : action.danger ? Theme.dangerText : Theme.textStrong
            }
        }
    }
}
