import QtQuick

// Selectable message text: pretty JSON or raw.
Rectangle {
    id: root

    property string text
    // Coloured rich text (e.g. Session.jsonStyled); when set it is shown instead of `text`.
    property string richText
    property bool touch: false
    property int fontSize: touch ? Theme.fontMd : Theme.fontSm

    implicitHeight: edit.implicitHeight + 24
    radius: touch ? Theme.radiusLg : Theme.radiusMd
    color: Theme.dark ? Theme.bg : Theme.surface
    border.width: 1
    border.color: Theme.border

    TextEdit {
        id: edit
        anchors.fill: parent
        anchors.margins: 12
        text: root.richText !== "" ? root.richText : root.text
        readOnly: true
        selectByMouse: true
        persistentSelection: true
        wrapMode: TextEdit.WrapAnywhere
        textFormat: root.richText !== "" ? TextEdit.RichText : TextEdit.PlainText
        font.family: Theme.mono
        font.pixelSize: root.fontSize
        color: Theme.text
        selectionColor: Theme.accentStrong
        selectedTextColor: Theme.textOnAccent
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("Message")
    }
}
