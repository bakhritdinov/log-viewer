import QtQuick

// Selectable message text: pretty JSON or raw.
Rectangle {
    id: root

    property string text
    property bool touch: false

    implicitHeight: edit.implicitHeight + 24
    radius: touch ? Theme.radiusLg : Theme.radiusMd
    color: Theme.dark ? Theme.bg : Theme.surface
    border.width: 1
    border.color: Theme.border

    TextEdit {
        id: edit
        anchors.fill: parent
        anchors.margins: 12
        text: root.text
        readOnly: true
        selectByMouse: true
        persistentSelection: true
        wrapMode: TextEdit.WrapAnywhere
        textFormat: TextEdit.PlainText
        font.family: Theme.mono
        font.pixelSize: root.touch ? Theme.fontMd : Theme.fontSm
        color: Theme.text
        selectionColor: Theme.accentStrong
        selectedTextColor: Theme.textOnAccent
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("Message")
    }
}
