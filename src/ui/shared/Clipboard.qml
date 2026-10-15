import QtQuick

// Copies text to the system clipboard (works in the browser build too).
Item {
    visible: false

    function copy(text) {
        buffer.text = text
        buffer.selectAll()
        buffer.copy()
        buffer.text = ""
    }

    TextEdit { id: buffer }
}
