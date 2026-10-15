import QtQuick

// Tiny bar trend (pattern rows, mobile header).
Row {
    id: root

    property var values: []
    property int maxValue: 1
    property color color: Theme.accent

    spacing: 1
    Accessible.ignored: true

    Repeater {
        model: root.values
        delegate: Rectangle {
            required property var modelData
            width: (root.width - root.spacing * (root.values.length - 1)) / Math.max(1, root.values.length)
            height: Math.max(1, root.height * modelData / Math.max(1, root.maxValue))
            anchors.bottom: parent ? parent.bottom : undefined
            color: root.color
            radius: 1
        }
    }
}
