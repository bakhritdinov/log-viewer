import QtQuick
import QtQuick.Controls.Basic

// A row of mutually exclusive options. `model`: list of {label, value} or
// strings. Arrow keys move the selection.
Control {
    id: control

    property var model: []
    property var value
    property bool touch: false
    property bool fill: false          // stretch options to the full width
    property string accessibleName

    signal activated(var value)

    function labelOf(item) { return typeof item === "object" ? item.label : String(item) }
    function valueOf(item) { return typeof item === "object" ? item.value : item }
    function indexOfValue(v) {
        for (let i = 0; i < model.length; ++i)
            if (valueOf(model[i]) === v) return i
        return -1
    }
    function select(i) {
        if (i < 0 || i >= model.length) return
        const v = valueOf(model[i])
        if (v === value) return
        value = v
        activated(v)
    }

    padding: 2
    focusPolicy: Qt.StrongFocus
    implicitHeight: (touch ? 40 : 26) + 2 * padding
    implicitWidth: row.implicitWidth + 2 * padding
    Accessible.role: Accessible.PageTabList
    Accessible.name: accessibleName
    Keys.onLeftPressed: select(indexOfValue(value) - 1)
    Keys.onRightPressed: select(indexOfValue(value) + 1)

    background: Rectangle {
        radius: control.touch ? Theme.radiusLg : Theme.radiusMd
        color: Theme.inputBg
        border.width: 1
        border.color: control.visualFocus ? Theme.focusRing : Theme.border
    }

    contentItem: Row {
        id: row
        Repeater {
            model: control.model
            delegate: AbstractButton {
                id: option
                required property var modelData
                required property int index
                readonly property bool current: control.valueOf(modelData) === control.value

                width: control.fill ? row.width / control.model.length : implicitWidth
                implicitWidth: optionText.implicitWidth + (control.touch ? 28 : 18)
                height: row.height
                focusPolicy: Qt.NoFocus
                checkable: false
                Accessible.role: Accessible.PageTab
                Accessible.name: optionText.text
                Accessible.selected: current
                onClicked: control.select(index)

                background: Rectangle {
                    radius: control.touch ? Theme.radiusMd + 2 : Theme.radiusSm
                    color: option.current ? Theme.hover : (option.hovered ? Theme.subtle : "transparent")
                }
                contentItem: Text {
                    id: optionText
                    text: control.labelOf(option.modelData)
                    font.family: Theme.sans
                    font.pixelSize: control.touch ? Theme.fontLg : Theme.fontSm
                    font.weight: Font.Medium
                    color: option.current ? Theme.textStrong : Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
