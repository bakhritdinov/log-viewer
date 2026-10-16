pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Search field with field/value suggestions and recent queries. Enter runs the
// search. Data comes in through properties; actions go out as signals.
FocusScope {
    id: root

    property alias text: input.text
    property var suggestions            // model: kind, field, value, count, completedText, exclude
    property var history: []            // recent search texts
    property var historyLabels: []      // the same on one line, as shown
    property bool touch: false
    property bool invalid: false        // the text was refused (red frame)
    property string placeholder: qsTr("Search: word, key:value, key:~regex, -key:value")

    signal submitted()
    signal suggestionActivated(int index, bool exclude)
    signal historyActivated(string text)

    readonly property bool popupOpen: popup.opened
    readonly property bool _hasPopupContent: list.count > 0 || historyRepeater.count > 0
    on_HasPopupContentChanged: if (!_hasPopupContent) popup.close()
    function _showPopup() { if (_hasPopupContent) popup.open() }
    function focusInput() { input.forceActiveFocus(); input.selectAll() }

    implicitHeight: touch ? 48 : 38
    implicitWidth: 480

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.touch ? Theme.radiusLg : Theme.radiusMd + 2
        color: Theme.inputBg
        border.width: 1
        border.color: root.invalid ? Theme.danger : input.activeFocus ? Theme.focusRing : Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 4
            spacing: 8

            Icon {
                name: "search"
                size: root.touch ? 18 : 16
                color: root.invalid ? Theme.danger : input.activeFocus ? Theme.accent : Theme.textMuted
            }
            TextInput {
                id: input
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.mono
                font.pixelSize: root.touch ? Theme.fontXl : Theme.fontMd
                color: Theme.textStrong
                selectionColor: Theme.accentStrong
                selectedTextColor: Theme.textOnAccent
                selectByMouse: true
                clip: true
                activeFocusOnTab: true          // TextInput is skipped by Tab otherwise
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Search logs")
                Keys.onReturnPressed: { popup.close(); root.submitted() }
                Keys.onEnterPressed: { popup.close(); root.submitted() }
                Keys.onEscapePressed: popup.close()
                Keys.onDownPressed: if (popup.opened) list.forceActiveFocus()
                // Tab completes the first suggestion without searching — once
                // something is typed: in an empty field it moves on, so the
                // keyboard is not trapped here.
                Keys.onTabPressed: event => {
                    if (popup.opened && list.count > 0 && input.text !== "") root.suggestionActivated(0, false)
                    else event.accepted = false
                }
                onActiveFocusChanged: if (activeFocus) root._showPopup()
                onTextEdited: root._showPopup()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: root.placeholder
                    font.family: Theme.sans
                    font.pixelSize: input.font.pixelSize
                    color: Theme.textMuted
                    elide: Text.ElideRight
                }
            }
            IconButton {
                visible: input.text !== ""
                iconName: "close"
                label: qsTr("Clear search")
                touch: root.touch
                onClicked: { input.clear(); input.forceActiveFocus() }
            }
        }
    }

    Popup {
        id: popup
        y: root.height + 4
        width: root.width
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Surface { elevated: true }

        contentItem: ColumnLayout {
            spacing: 4

            SectionLabel {
                Layout.leftMargin: 6
                visible: list.count > 0
                text: list.count > 0 && root.suggestions.get(0).kind === "value"
                      ? qsTr("%1 · %n value(s)", "", list.count).arg(root.suggestions.get(0).field)
                      : qsTr("Fields")
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 320)
                clip: true
                model: root.suggestions
                keyNavigationWraps: true
                Keys.onReturnPressed: event => root.suggestionActivated(currentIndex, (event.modifiers & Qt.ShiftModifier) !== 0)
                Keys.onTabPressed: root.suggestionActivated(currentIndex, false)
                Keys.onUpPressed: if (currentIndex === 0) input.forceActiveFocus(); else decrementCurrentIndex()

                delegate: ItemDelegate {
                    id: suggestion
                    // Basic's 12 px vertical padding pushes the content below the row's centre.
                    topPadding: 0
                    bottomPadding: 0
                    hoverEnabled: true
                    required property int index
                    required property string kind
                    required property string field
                    required property string value
                    required property int count

                    width: ListView.view.width
                    height: root.touch ? 52 : 34
                    highlighted: ListView.isCurrentItem
                    Accessible.name: kind === "field" ? qsTr("Field %1").arg(field) : qsTr("%1 = %2").arg(field).arg(value)
                    onClicked: root.suggestionActivated(index, false)

                    background: Rectangle {
                        radius: Theme.radiusMd
                        color: suggestion.highlighted || suggestion.hovered ? Theme.subtle : "transparent"
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        Rectangle {
                            visible: suggestion.kind === "value" && suggestion.field === "level"
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 2
                            color: Theme.levelColor(suggestion.value.toUpperCase())
                        }
                        Text {
                            Layout.fillWidth: true
                            text: suggestion.kind === "field" ? suggestion.field + ":" : suggestion.value
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontMd
                            color: Theme.textStrong
                            elide: Text.ElideRight
                        }
                        Text {
                            text: suggestion.kind === "field" ? qsTr("%n value(s)", "", suggestion.count)
                                                              : suggestion.count.toLocaleString(Qt.locale(), "f", 0)
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            color: Theme.textMuted
                        }
                        IconButton {
                            visible: suggestion.kind === "value"
                            iconName: "plus"
                            label: qsTr("Show only %1").arg(suggestion.value)
                            touch: root.touch
                            iconColor: Theme.accent
                            onClicked: root.suggestionActivated(suggestion.index, false)
                        }
                        IconButton {
                            visible: suggestion.kind === "value"
                            iconName: "minus"
                            label: qsTr("Exclude %1").arg(suggestion.value)
                            touch: root.touch
                            iconColor: Theme.dangerText
                            onClicked: root.suggestionActivated(suggestion.index, true)
                        }
                    }
                }
            }

            SectionLabel {
                Layout.leftMargin: 6
                Layout.topMargin: list.count > 0 ? 4 : 0
                visible: list.count === 0 && historyRepeater.count > 0
                text: qsTr("Recent searches")
            }
            Repeater {
                id: historyRepeater
                model: list.count === 0 ? root.history.slice(0, 8) : []
                delegate: ItemDelegate {
                    id: recent
                    required property int index
                    // Basic's 12 px vertical padding pushes the content below the row's centre.
                    topPadding: 0
                    bottomPadding: 0
                    hoverEnabled: true
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: root.touch ? 44 : 32
                    onClicked: { popup.close(); root.historyActivated(modelData) }
                    background: Rectangle {
                        radius: Theme.radiusMd
                        color: recent.hovered ? Theme.subtle : "transparent"
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        Icon { name: "history"; size: 14; color: Theme.textMuted }
                        Text {
                            Layout.fillWidth: true
                            text: root.historyLabels[recent.index] ?? recent.modelData
                            maximumLineCount: 1
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontMd
                            color: Theme.text
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            // Key hints
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: !root.touch
                implicitHeight: 1
                color: Theme.borderMuted
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.topMargin: 2
                visible: !root.touch
                text: list.count === 0 ? qsTr("↑ ↓ choose · Enter search · Esc close")
                    : root.suggestions.get(0).kind === "value" ? qsTr("Enter show only · Shift+Enter exclude · Esc close")
                    : qsTr("Tab complete · Enter search as typed · Esc close")
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: Theme.fontXs
                color: Theme.textMuted
            }
        }
    }
}
