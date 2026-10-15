import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// One notice at a time above the navigation: 4 s, 8 s with an action.
Rectangle {
    id: root

    property var action: null

    function show(text, actionText, act) {
        label.text = text
        actionButton.text = actionText
        root.action = act
        timer.interval = actionText !== "" ? 8000 : 4000
        timer.restart()
        root.shown = true
    }

    property bool shown: false

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    implicitHeight: Math.max(48, row.implicitHeight + 16)
    radius: Theme.radiusLg
    color: Theme.tooltipBg
    border.width: 1
    border.color: Theme.tooltipBorder
    Accessible.role: Accessible.AlertMessage
    Accessible.name: label.text

    Timer { id: timer; onTriggered: root.shown = false }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 4
        spacing: 8
        Text {
            id: label
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontLg
            color: Theme.tooltipText
        }
        AppButton {
            id: actionButton
            visible: text !== ""
            variant: "link"
            touch: true
            onClicked: {
                if (root.action) root.action()
                root.shown = false
            }
        }
    }
}
