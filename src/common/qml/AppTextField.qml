import QtQuick
import QtQuick.Controls
import LogViewerApp

TextField {
    id: root
    color: Theme.text
    selectionColor: Theme.accent
    selectedTextColor: Theme.textOnAccent
    font.pixelSize: Theme.fsMd
    leftPadding: Theme.sp3
    rightPadding: Theme.sp3
    verticalAlignment: TextInput.AlignVCenter
    placeholderTextColor: Theme.textDim

    background: Rectangle {
        color: Theme.bgInput
        border.color: root.activeFocus ? Theme.borderFocus : Theme.border
        border.width: 1
        radius: Theme.rMd
        Behavior on border.color { ColorAnimation { duration: Theme.dFast } }
    }
}
