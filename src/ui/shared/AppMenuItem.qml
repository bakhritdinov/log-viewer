import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// One row of an AppMenu: optional check mark or colour dot, text, hint.
AbstractButton {
    id: control

    property bool checkedMark: false      // shows a check mark column
    property color dotColor: "transparent"
    property string hint
    property bool danger: false
    property bool hintDanger: false      // the hint as a red badge ("LIVE")
    property string iconName             // a leading icon instead of the check column

    signal triggered()

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth + leftPadding + rightPadding
    implicitHeight: 32
    leftPadding: 8
    rightPadding: 12
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.MenuItem
    Accessible.name: text
    Accessible.checked: checkedMark

    onClicked: {
        triggered()
        // The AppMenu's column exposes the menu to close.
        const menu = parent ? parent.menu : null // qmllint disable missing-property
        if (menu) menu.close()
    }

    background: Rectangle {
        radius: Theme.radiusMd
        color: control.enabled && (control.hovered || control.visualFocus) ? Theme.subtle : "transparent"
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.focusRing
    }

    contentItem: RowLayout {
        id: row
        spacing: 8
        Item {
            implicitWidth: 16
            implicitHeight: 16
            Icon {
                anchors.centerIn: parent
                visible: control.iconName !== ""
                name: control.iconName
                size: 14
                color: !control.enabled ? Theme.textDisabled : control.danger ? Theme.dangerText : Theme.textMuted
            }
            Icon {
                anchors.centerIn: parent
                visible: control.checkedMark && control.dotColor.a === 0
                name: "check"
                size: 14
                strokeWidth: 2.4
                color: Theme.success
            }
            Rectangle {
                anchors.centerIn: parent
                visible: control.dotColor.a > 0
                width: 8; height: 8; radius: 4
                color: control.dotColor
            }
        }
        Text {
            Layout.fillWidth: true
            text: control.text
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            font.weight: control.checkedMark ? Font.DemiBold : Font.Normal
            color: !control.enabled ? Theme.textDisabled : control.danger ? Theme.dangerText : control.checkedMark ? Theme.textStrong : Theme.text
        }
        Icon {
            visible: control.checkedMark && control.dotColor.a > 0
            name: "check"
            size: 14
            strokeWidth: 2.4
            color: Theme.success
        }
        Item { Layout.fillWidth: true; visible: control.hint !== "" }
        Rectangle {
            visible: control.hint !== ""
            implicitWidth: hintText.implicitWidth + (control.hintDanger ? 10 : 0)
            implicitHeight: hintText.implicitHeight + (control.hintDanger ? 2 : 0)
            radius: Theme.radiusSm
            color: "transparent"
            border.width: control.hintDanger ? 1 : 0
            border.color: Theme.dangerBorder
            Text {
                id: hintText
                anchors.centerIn: parent
                text: control.hint
                font.family: Theme.mono
                font.pixelSize: Theme.fontXs
                color: control.hintDanger ? Theme.dangerText : Theme.textMuted
            }
        }
    }
}
