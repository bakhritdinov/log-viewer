import QtQuick

// Selectable message text: pretty JSON or raw.
Rectangle {
    id: root

    property string text
    // Coloured rich text (e.g. Session.jsonStyled); when set it is shown instead of `text`.
    property string richText
    property bool touch: false
    property int fontSize: touch ? Theme.fontMd : Theme.fontSm

    implicitHeight: (richText !== "" ? richEdit.implicitHeight : edit.implicitHeight) + 24
    radius: touch ? Theme.radiusLg : Theme.radiusMd
    color: Theme.dark ? Theme.bg : Theme.surface
    border.width: 1
    border.color: Theme.border

    // Two editors, not one switching its format: going from rich to plain text
    // left the HTML source showing.
    TextEdit {
        id: edit
        anchors.fill: parent
        anchors.margins: 12
        visible: root.richText === ""
        text: root.text
        textFormat: TextEdit.PlainText
        readOnly: true
        selectByMouse: true
        persistentSelection: true
        wrapMode: TextEdit.WrapAnywhere
        font.family: Theme.mono
        font.pixelSize: root.fontSize
        color: Theme.text
        selectionColor: Theme.accentStrong
        selectedTextColor: Theme.textOnAccent
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("Message")
    }
    TextEdit {
        id: richEdit
        anchors.fill: parent
        anchors.margins: 12
        visible: root.richText !== ""
        text: root.richText
        textFormat: TextEdit.RichText
        readOnly: true
        selectByMouse: true
        persistentSelection: true
        wrapMode: TextEdit.WrapAnywhere
        font.family: Theme.mono
        font.pixelSize: root.fontSize
        color: Theme.text
        selectionColor: Theme.accentStrong
        selectedTextColor: Theme.textOnAccent
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("Message")
    }
}
