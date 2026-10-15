import QtQuick

// The search conditions as chips (model: text, exclude). Wraps on narrow widths.
Flow {
    id: root

    property var model
    property bool touch: false

    signal removeRequested(int index)

    spacing: 6

    Repeater {
        model: root.model
        delegate: FilterChip {
            required property int index
            required property var model
            text: model.text
            exclude: model.exclude
            touch: root.touch
            onRemoveRequested: root.removeRequested(index)
        }
    }
}
