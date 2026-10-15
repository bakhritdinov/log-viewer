import QtQuick

// Raised panel: card, popover body, list group.
Rectangle {
    property bool raised: true
    property bool elevated: false   // popovers: stronger border

    color: raised ? Theme.surface : Theme.bg
    radius: Theme.radiusLg
    border.width: 1
    border.color: elevated ? Theme.border : Theme.borderMuted
}
