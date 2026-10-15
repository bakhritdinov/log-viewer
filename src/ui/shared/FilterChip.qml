import QtQuick
import QtQuick.Controls.Basic

// A search condition shown as a removable chip; exclusions are red.
Control {
    id: control

    required property string text
    property bool exclude: false
    property bool touch: false
    property bool pill: true                // false: rounded corners like the buttons next to it

    signal removeRequested()

    implicitHeight: touch ? 32 : 24
    implicitWidth: label.implicitWidth + removeButton.implicitWidth + leftPadding + 2
    leftPadding: touch ? 10 : 9
    font.family: Theme.mono
    font.pixelSize: Theme.fontSm
    Accessible.role: Accessible.StaticText
    Accessible.name: (exclude ? qsTr("Excluded: %1") : qsTr("Filter: %1")).arg(text)

    readonly property color _fg: exclude ? Theme.dangerText : Theme.accentText

    background: Rectangle {
        radius: control.pill ? height / 2 : Theme.radiusMd
        color: control.exclude ? Theme.dangerSoft : Theme.accentSoft
        border.width: 1
        border.color: control.exclude ? Theme.dangerBorder : Theme.accentBorder
    }

    contentItem: Item {
        Text {
            id: label
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font: control.font
            color: control._fg
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 320)
        }
        Button {
            id: removeButton
            anchors.left: label.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: control.touch ? 32 : 22
            implicitHeight: implicitWidth
            padding: 0
            Accessible.name: qsTr("Remove filter %1").arg(control.text)
            onClicked: control.removeRequested()
            contentItem: Item {
                Icon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 10
                    strokeWidth: 3
                    color: control._fg
                }
            }
            background: Rectangle {
                radius: width / 2
                color: removeButton.hovered ? Theme.tint(control._fg, 0.18) : "transparent"
            }
        }
    }
}
