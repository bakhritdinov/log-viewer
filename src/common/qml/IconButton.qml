import QtQuick
import QtQuick.Controls
import LogViewerApp

Button {
    id: root

    property string tooltipText: ""
    property color  iconColor: Theme.textMuted
    property color  iconHoverColor: Theme.accent
    property color  iconActiveColor: Theme.accent
    property bool   active: false
    property int    pixel: Theme.fsLg
    property int    boxSize: 28

    implicitWidth: boxSize
    implicitHeight: boxSize
    flat: true
    hoverEnabled: true

    ToolTip.visible: hovered && tooltipText !== ""
    ToolTip.text: tooltipText
    ToolTip.delay: 400

    background: Rectangle {
        color: root.active ? Theme.bgHover
             : (root.hovered ? Theme.bgSubtle : "transparent")
        radius: Theme.rSm
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }

    contentItem: Text {
        text: root.text
        color: root.active ? root.iconActiveColor
             : (root.hovered ? root.iconHoverColor : root.iconColor)
        font.pixelSize: root.pixel
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }
}
