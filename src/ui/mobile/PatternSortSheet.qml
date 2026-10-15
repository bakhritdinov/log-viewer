pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The order of the patterns; a choice applies at once and closes the sheet.
BottomSheet {
    id: root

    title: qsTr("Sort the patterns")

    Repeater {
        model: [
            { label: qsTr("By count"), value: "count" },
            { label: qsTr("By first appearance"), value: "first" },
            { label: qsTr("By last appearance"), value: "last" },
            { label: qsTr("By level (ERROR first)"), value: "level" },
        ]
        delegate: AbstractButton {
            id: option
            required property var modelData
            readonly property bool current: Session.patternSort === modelData.value
            Layout.fillWidth: true
            implicitHeight: 48
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.label
            Accessible.checked: current
            onClicked: { Session.patternSort = modelData.value; root.close() }
            background: Rectangle { color: option.pressed ? Theme.subtle : "transparent" }
            contentItem: RowLayout {
                spacing: 12
                Icon { Layout.leftMargin: 18; name: "check"; size: 18; color: Theme.accentText; opacity: option.current ? 1 : 0 }
                Text {
                    Layout.fillWidth: true
                    text: option.modelData.label
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontLg + 1
                    font.weight: option.current ? Font.DemiBold : Font.Normal
                    color: Theme.textStrong
                }
            }
        }
    }
    Item { implicitHeight: 12 }
}
