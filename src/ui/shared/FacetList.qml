pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Fields of the loaded entries with their values (model: field, distinct,
// expanded, values[{value, count, share, active, excluded}]).
ListView {
    id: root

    property bool touch: false

    signal toggleExpanded(string field)
    signal valueActivated(string field, string value, bool exclude)

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    Accessible.role: Accessible.Tree
    Accessible.name: qsTr("Fields")

    delegate: ColumnLayout {
        id: fieldItem
        required property string field
        required property int distinct
        required property bool expanded
        required property var values

        width: ListView.view.width
        spacing: 2

        ItemDelegate {
            id: header
            Layout.fillWidth: true
            implicitHeight: root.touch ? 48 : 28
            Accessible.role: Accessible.TreeItem
            Accessible.name: qsTr("%1, %n value(s)", "", fieldItem.distinct).arg(fieldItem.field)
            onClicked: root.toggleExpanded(fieldItem.field)
            background: Rectangle {
                radius: Theme.radiusMd
                color: header.hovered ? Theme.subtle : (root.touch ? Theme.surface : "transparent")
            }
            contentItem: RowLayout {
                spacing: 6
                Icon {
                    name: "chevronRight"
                    size: 12
                    color: Theme.textMuted
                    rotation: fieldItem.expanded ? 90 : 0
                }
                Text {
                    Layout.fillWidth: true
                    text: fieldItem.field
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: root.touch ? Theme.fontLg : Theme.fontMd
                    color: Theme.textStrong
                }
                Text {
                    text: fieldItem.distinct
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                    color: Theme.textMuted
                }
            }
        }

        Repeater {
            model: fieldItem.expanded ? fieldItem.values : []
            delegate: ItemDelegate {
                id: valueItem
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: root.touch ? 24 : 18
                implicitHeight: root.touch ? 44 : 26
                Accessible.name: qsTr("%1 = %2, %3 entries").arg(fieldItem.field).arg(modelData.value).arg(modelData.count)
                onClicked: root.valueActivated(fieldItem.field, modelData.value, false)

                background: Rectangle {
                    radius: Theme.radiusSm
                    color: valueItem.modelData.active ? Theme.accentSoft
                         : valueItem.modelData.excluded ? Theme.dangerSoft
                         : (valueItem.hovered ? Theme.subtle : "transparent")
                    border.width: valueItem.modelData.active || valueItem.modelData.excluded ? 1 : 0
                    border.color: valueItem.modelData.excluded ? Theme.dangerBorder : Theme.accentBorder
                }
                contentItem: RowLayout {
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: valueItem.modelData.value
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        color: valueItem.modelData.active ? Theme.accentText
                             : valueItem.modelData.excluded ? Theme.dangerText : Theme.text
                    }
                    Rectangle {
                        implicitWidth: 40 * valueItem.modelData.share + 2
                        implicitHeight: 4
                        radius: 2
                        color: Theme.border
                    }
                    Text {
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                        text: valueItem.modelData.count.toLocaleString(Qt.locale(), "f", 0)
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontXs
                        color: Theme.textMuted
                    }
                    IconButton {
                        visible: root.touch || valueItem.hovered
                        iconName: "minus"
                        label: qsTr("Exclude %1").arg(valueItem.modelData.value)
                        touch: root.touch
                        implicitWidth: root.touch ? Theme.touchHeight : 22
                        iconColor: Theme.dangerText
                        onClicked: root.valueActivated(fieldItem.field, valueItem.modelData.value, true)
                    }
                }
            }
        }
    }
}
