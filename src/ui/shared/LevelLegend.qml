pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Level totals that double as level filters (one active at a time).
GridLayout {
    id: root

    property var totals: ({})           // {ERROR: n, WARN: n, …}
    property string activeLevel
    property bool touch: false

    signal toggled(string level)

    // WARN and above, as in 2.8; a level without entries is not shown.
    readonly property var levels: ["ERROR", "WARN"]

    columns: 2
    columnSpacing: touch ? 8 : 4
    rowSpacing: 8

    Repeater {
        model: root.levels
        delegate: Button {
            id: chip
            required property string modelData
            readonly property bool active: root.activeLevel === modelData
            readonly property int count: root.totals[modelData] ?? 0

            Layout.fillWidth: root.touch
            visible: count > 0 || active
            implicitHeight: root.touch ? Theme.touchHeight : 24
            implicitWidth: row.implicitWidth + 16
            Accessible.role: Accessible.CheckBox
            Accessible.checked: active
            Accessible.name: qsTr("%1: %2").arg(modelData).arg(count)
            onClicked: root.toggled(modelData)

            background: Rectangle {
                radius: root.touch ? Theme.radiusLg : Theme.radiusMd
                color: chip.active ? Theme.levelSoft(chip.modelData) : (root.touch ? Theme.surface : (chip.hovered ? Theme.subtle : "transparent"))
                border.width: 1
                border.color: chip.visualFocus ? Theme.focusRing : (chip.active ? Theme.levelColor(chip.modelData) : Theme.border)
            }
            contentItem: RowLayout {
                id: row
                spacing: 6
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 2
                    color: Theme.levelColor(chip.modelData)
                }
                Text {
                    Layout.fillWidth: root.touch
                    // Name and count share a baseline although their fonts differ.
                    Layout.alignment: Qt.AlignBaseline
                    text: chip.modelData
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Medium
                    color: chip.active ? Theme.textStrong : Theme.text
                }
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    text: chip.count.toLocaleString(Qt.locale(), "f", 0)
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
        }
    }
}
