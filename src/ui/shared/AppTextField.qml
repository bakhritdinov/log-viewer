import QtQuick
import QtQuick.Controls.Basic

// Single-line input. `mono` for queries, ids and URLs.
TextField {
    id: control

    property bool touch: false
    property bool mono: false
    property bool invalid: false

    implicitHeight: touch ? 48 : Theme.inputHeight
    leftPadding: 12
    rightPadding: 12
    font.family: mono ? Theme.mono : Theme.sans
    font.pixelSize: touch ? Theme.fontXl : Theme.fontMd   // 16 px on touch: no iOS zoom-in
    color: Theme.textStrong
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.accentStrong
    selectedTextColor: Theme.textOnAccent
    selectByMouse: true

    background: Rectangle {
        radius: control.touch ? Theme.radiusLg : Theme.radiusMd
        color: Theme.inputBg
        border.width: 1
        border.color: control.invalid ? Theme.danger
                    : control.activeFocus ? Theme.focusRing : Theme.border
    }
}
