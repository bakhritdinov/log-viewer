import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Dropdown in the app's look (the stock Menu is unthemed). Items are laid out
// in declaration order, Repeaters included; an AppMenuItem closes the menu.
Popup {
    id: root

    default property alias items: column.data
    property int minimumWidth: 200

    padding: 4
    implicitWidth: Math.max(minimumWidth, column.implicitWidth + leftPadding + rightPadding)
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Surface { elevated: true; radius: Theme.radiusLg }

    contentItem: ColumnLayout {
        id: column
        readonly property Popup menu: root
        spacing: 1
        Accessible.role: Accessible.PopupMenu
    }
}
