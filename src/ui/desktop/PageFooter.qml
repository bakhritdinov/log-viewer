import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Paging over the loaded entries ([ ] keys), loading progress and
// "load more" from the server.
Rectangle {
    id: root

    readonly property var logs: Session.logs

    implicitHeight: 44
    color: Theme.bg

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.borderMuted }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: {
                if (Session.loading)
                    return qsTr("Loaded %1 entries…").arg(root.logs.loadedCount.toLocaleString(Qt.locale(), "f", 0))
                if (root.logs.totalCount === 0) return ""
                const shown = qsTr("Showing %1–%2 of %3 loaded")
                    .arg(root.logs.firstRowNumber.toLocaleString(Qt.locale(), "f", 0))
                    .arg(root.logs.lastRowNumber.toLocaleString(Qt.locale(), "f", 0))
                    .arg(root.logs.totalCount.toLocaleString(Qt.locale(), "f", 0))
                return Session.hasMore ? qsTr("%1 · the period has more").arg(shown) : shown
            }
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
        }

        AppButton {
            visible: Session.loading
            text: qsTr("Stop")
            onClicked: Session.stopLoading()
        }

        Row {
            visible: root.logs.pageCount > 1
            spacing: 4
            IconButton {
                iconName: "chevronsLeft"; label: qsTr("First page (Shift+[)")
                enabled: root.logs.page > 0
                onClicked: root.logs.goToPage(0)
            }
            IconButton {
                iconName: "chevronLeft"; label: qsTr("Newer ([)")
                enabled: root.logs.page > 0
                onClicked: root.logs.goToPage(root.logs.page - 1)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Page")
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textMuted
            }
            AppTextField {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 48
                implicitHeight: 28
                horizontalAlignment: TextInput.AlignHCenter
                mono: true
                text: root.logs.page + 1
                validator: IntValidator { bottom: 1; top: root.logs.pageCount }
                Accessible.name: qsTr("Page number")
                onAccepted: root.logs.goToPage(Number(text) - 1)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("of %1").arg(root.logs.pageCount)
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: Theme.textMuted
            }
            IconButton {
                iconName: "chevronRight"; label: qsTr("Older (])")
                enabled: root.logs.page < root.logs.pageCount - 1
                onClicked: root.logs.goToPage(root.logs.page + 1)
            }
            IconButton {
                iconName: "chevronsRight"; label: qsTr("Last page (Shift+])")
                enabled: root.logs.page < root.logs.pageCount - 1
                onClicked: root.logs.goToPage(root.logs.pageCount - 1)
            }
        }

        AppButton {
            visible: Session.hasMore && !Session.loading
            text: qsTr("Load %1 more").arg(Session.loadStep.toLocaleString(Qt.locale(), "f", 0))
            onClicked: Session.loadMore()
        }
    }
}
