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

    // For the button that opens it: a second click closes it. (A press on that
    // button is not "outside", so the menu stays open for the click to decide.)
    function toggle() { if (opened) close(); else open() }

    background: Surface { elevated: true; radius: Theme.radiusLg }

    contentItem: ColumnLayout {
        id: column
        readonly property Popup menu: root
        spacing: 1
        Accessible.role: Accessible.PopupMenu
    }
}
