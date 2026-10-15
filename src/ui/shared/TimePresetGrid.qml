pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Preset periods as a grid of toggles; `currentKey` is highlighted.
GridLayout {
    id: root

    property string currentKey
    property bool touch: false
    property bool compactLabels: touch     // "1 h" on phones, "Last 1 hour" on desktop

    signal picked(string key)

    readonly property var presets: [
        { key: "5m", long: qsTr("Last 5 minutes"), short: qsTr("5 min") },
        { key: "15m", long: qsTr("Last 15 minutes"), short: qsTr("15 min") },
        { key: "30m", long: qsTr("Last 30 minutes"), short: qsTr("30 min") },
        { key: "1h", long: qsTr("Last 1 hour"), short: qsTr("1 hour") },
        { key: "3h", long: qsTr("Last 3 hours"), short: qsTr("3 hours") },
        { key: "6h", long: qsTr("Last 6 hours"), short: qsTr("6 hours") },
        { key: "12h", long: qsTr("Last 12 hours"), short: qsTr("12 hours") },
        { key: "1d", long: qsTr("Last 24 hours"), short: qsTr("24 hours") },
        { key: "2d", long: qsTr("Last 2 days"), short: qsTr("2 days") },
        { key: "7d", long: qsTr("Last 7 days"), short: qsTr("7 days") },
        { key: "today", long: qsTr("Today"), short: qsTr("Today") },
        { key: "yesterday", long: qsTr("Yesterday"), short: qsTr("Yesterday") },
    ]

    columns: touch ? 3 : 1
    columnSpacing: 8
    rowSpacing: touch ? 8 : 2

    Repeater {
        model: root.presets
        delegate: Button {
            id: preset
            required property var modelData
            readonly property bool current: modelData.key === root.currentKey

            Layout.fillWidth: true
            implicitHeight: root.touch ? Theme.touchHeight : 30
            text: root.compactLabels ? modelData.short : modelData.long
            checkable: false
            Accessible.role: Accessible.RadioButton
            Accessible.checked: current
            onClicked: root.picked(modelData.key)

            contentItem: Text {
                text: preset.text
                font.family: Theme.sans
                font.pixelSize: root.touch ? Theme.fontLg : Theme.fontMd
                font.weight: Font.Medium
                color: preset.current ? Theme.successText : Theme.text
                horizontalAlignment: root.touch ? Text.AlignHCenter : Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                leftPadding: root.touch ? 0 : 10
            }
            background: Rectangle {
                radius: root.touch ? Theme.radiusLg : Theme.radiusMd
                color: preset.current ? Theme.successSoft : (preset.hovered ? Theme.subtle : (root.touch ? Theme.subtle : "transparent"))
                border.width: root.touch || preset.visualFocus ? 1 : 0
                border.color: preset.visualFocus ? Theme.focusRing : (preset.current ? Theme.successBorder : Theme.border)
            }
        }
    }
}
