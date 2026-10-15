import QtQuick
import QtQuick.Controls.Basic

// Hover hint in the app's look: a dark chip under its control with the text and,
// optionally, the shortcut. Declare it inside the control:
//     AppToolTip { visible: control.hovered; text: qsTr("Refresh"); shortcut: "F5" }
ToolTip {
    id: root

    property string shortcut

    delay: 500
    topPadding: 5
    bottomPadding: 5
    leftPadding: 9
    rightPadding: 9
    x: parent ? Math.round((parent.width - width) / 2) : 0
    // Below the control; above it when the window has no room underneath.
    y: {
        if (!parent) return 0
        const bottom = parent.mapToItem(null, 0, parent.height).y + 6 + implicitHeight
        return bottom > parent.Window.height - margins ? -implicitHeight - 6 : parent.height + 6
    }
    margins: 8

    contentItem: Row {
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 320)
            text: root.text
            wrapMode: Text.Wrap
            lineHeight: 1.15
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.tooltipText
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.shortcut !== ""
            implicitWidth: Math.ceil(keyText.implicitWidth) + 10
            implicitHeight: Math.ceil(keyText.implicitHeight) + 4
            radius: Theme.radiusSm
            color: Theme.dark ? Theme.subtle : "#32383f"
            border.width: 1
            border.color: Theme.tooltipBorder
            Text {
                id: keyText
                anchors.centerIn: parent
                text: root.shortcut
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                font.weight: Font.Medium
                color: Theme.tooltipText
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusMd
        color: Theme.tooltipBg
        border.width: 1
        border.color: Theme.tooltipBorder
    }
}
