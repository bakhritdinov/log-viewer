pragma ComponentBehavior: Bound
import QtQuick

// Tiny bar trend (pattern rows, mobile header).
Row {
    id: root

    property var values: []
    property int maxValue: 1
    property color color: Theme.accent
    property var colors: []             // per bar, over `color`

    spacing: 1
    Accessible.ignored: true

    Repeater {
        model: root.values
        delegate: Rectangle {
            required property var modelData
            width: (root.width - root.spacing * (root.values.length - 1)) / Math.max(1, root.values.length)
            height: Math.max(1, root.height * modelData / Math.max(1, root.maxValue))
            anchors.bottom: parent ? parent.bottom : undefined
            required property int index
            color: root.colors[index] ?? root.color
            radius: 1
        }
    }
}
