pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The search on the whole screen, opened by tapping the search row. Empty
// field: save / share and the saved and recent queries. While typing: levels,
// the fields or values for the last word, other fields, recent queries. "Find"
// (Enter or the bar above the keyboard) searches and goes back to the feed;
// a refused query keeps the screen open and says why.
Popup {
    id: root

    signal saveRequested()
    signal shareRequested()
    signal savedQueryMenuRequested(string id)

    function search() {
        Session.search()
        if (Session.searchError === "") close()
    }
    // Types `s` where the cursor is (the symbols the phone keyboard hides).
    function insert(s) {
        const at = input.cursorPosition
        Session.searchText = Session.searchText.slice(0, at) + s + Session.searchText.slice(at)
        input.cursorPosition = at + s.length
        input.forceActiveFocus()
    }
    // A field from "Other fields": a new condition at the end of the query.
    function addField(field) {
        const text = Session.searchText.trim()
        Session.searchText = (text === "" ? "" : text + " AND ") + field + ":"
        input.cursorPosition = Session.searchText.length
        input.forceActiveFocus()
    }
    function levelOn(level) {
        for (let i = 0; i < Session.chips.count; ++i) {
            const c = Session.chips.get(i)
            if (c.field === "level" && String(c.value).toLowerCase() === level && !c.exclude) return true
        }
        return false
    }

    readonly property bool typing: Session.searchText.trim() !== ""
    readonly property bool valueSuggestions: Session.suggestions.count > 0 && Session.suggestions.get(0).kind === "value"
    // An unclosed quote can be closed with one tap.
    readonly property bool openQuote: (Session.searchText.split("\"").length - 1) % 2 === 1
    // The text before the search started: "Cancel" goes back to it.
    property string textBefore

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape
    onAboutToShow: textBefore = Session.searchText
    onOpened: { input.forceActiveFocus(); input.cursorPosition = input.length }
    background: Rectangle { color: Theme.bg }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }

    contentItem: ColumnLayout {
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Search")

        // The field and Cancel.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            color: Theme.surface
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusLg
                    color: Theme.inputBg
                    border.width: 1
                    border.color: Session.searchError !== "" ? Theme.danger : Theme.accent
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 2
                        spacing: 8
                        Icon { name: "search"; size: 18; color: Theme.accentText }
                        TextInput {
                            id: input
                            activeFocusOnTab: true
                            Layout.fillWidth: true
                            clip: true
                            text: Session.searchText
                            onTextEdited: Session.searchText = text
                            font.family: Theme.mono
                            font.pixelSize: 16             // smaller: iOS Safari zooms in on focus
                            color: Theme.textStrong
                            selectionColor: Theme.accentSoft
                            selectedTextColor: Theme.textStrong
                            // No autocorrection or capital first letter in a query.
                            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhPreferLatin
                            Accessible.role: Accessible.EditableText
                            Accessible.name: qsTr("Search the logs")
                            onAccepted: root.search()
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: input.text === ""
                                text: qsTr("Word, key:value…")
                                font: input.font
                                color: Theme.textDisabled
                            }
                        }
                        IconButton {
                            visible: input.text !== ""
                            touch: true
                            iconName: "close"
                            label: qsTr("Clear")
                            onClicked: { Session.searchText = ""; input.forceActiveFocus() }
                        }
                    }
                }
                AppButton {
                    variant: "link"
                    touch: true
                    text: qsTr("Cancel")
                    onClicked: { Session.searchText = root.textBefore; root.close() }
                }
            }
        }

        Flickable {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: content
                x: 16
                y: 12
                width: body.width - 32
                spacing: 18

                // A refused query: why, and the quick fix when there is one.
                Rectangle {
                    Layout.fillWidth: true
                    visible: Session.searchError !== ""
                    implicitHeight: errorColumn.implicitHeight + 24
                    radius: Theme.radiusLg
                    color: Theme.dangerSoft
                    border.width: 1
                    border.color: Theme.dangerBorder
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: Session.searchError
                    ColumnLayout {
                        id: errorColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            text: Session.searchError
                            wrapMode: Text.Wrap
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontLg
                            color: Theme.textStrong
                        }
                        AppButton {
                            visible: root.openQuote
                            touch: true
                            text: qsTr("Close the quote")
                            onClicked: { Session.searchText = Session.searchText + "\""; root.search() }
                        }
                    }
                }

                // ── an empty field: save / share, saved, recent ──
                GridLayout {
                    Layout.fillWidth: true
                    visible: !root.typing
                    columns: 2
                    columnSpacing: 8
                    AppButton {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        touch: true
                        iconName: "star"
                        text: qsTr("Save current")
                        enabled: Session.namespaceName !== ""
                        onClicked: root.saveRequested()
                    }
                    AppButton {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        touch: true
                        iconName: "share"
                        text: qsTr("Share")
                        enabled: Session.namespaceName !== ""
                        onClicked: root.shareRequested()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: -8
                    visible: !root.typing
                    text: qsTr("The link holds the environment by name, the source, the query and the period — no passwords.")
                    wrapMode: Text.Wrap
                    lineHeight: 1.15
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.typing && Session.savedQueries.count > 0
                    spacing: 8
                    Caption { text: qsTr("Saved") }
                    ListFrame {
                        Repeater {
                            model: Session.savedQueries
                            delegate: SavedRow { }
                        }
                    }
                }

                // ── typing: levels, fields or values, other fields ──
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.typing
                    spacing: 8
                    Caption { text: qsTr("Level") }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: ["error", "warn", "info", "debug"]
                            delegate: AbstractButton {
                                id: levelButton
                                required property string modelData
                                readonly property bool on: root.levelOn(modelData)
                                Layout.fillWidth: true
                                implicitHeight: 44
                                checkable: false
                                Accessible.name: modelData.toUpperCase()
                                Accessible.checked: on
                                onClicked: Session.toggleFilter("level", modelData, false)
                                background: Rectangle {
                                    radius: Theme.radiusLg
                                    color: levelButton.pressed ? Theme.hover
                                         : levelButton.on ? Theme.tint(Theme.levelColor(levelButton.modelData.toUpperCase()), 0.12) : Theme.surface
                                    border.width: 1
                                    border.color: levelButton.on ? Theme.levelColor(levelButton.modelData.toUpperCase()) : Theme.border
                                }
                                contentItem: Item {
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 8; height: 8; radius: 2
                                            color: Theme.levelColor(levelButton.modelData.toUpperCase())
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: levelButton.modelData.toUpperCase()
                                            font.family: Theme.sans
                                            font.pixelSize: Theme.fontSm
                                            font.weight: Font.DemiBold
                                            color: Theme.textStrong
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Fields matching the last word, or the values of "field:".
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.typing && Session.suggestions.count > 0
                    spacing: 8
                    Caption {
                        textFormat: Text.StyledText
                        text: {
                            if (!root.valueSuggestions) return qsTr("Fields")
                            const s = Session.suggestions.get(0)
                            const typed = Session.searchText.slice(Session.searchText.lastIndexOf(":") + 1).replace(/"/g, "")
                            const field = "<font color=\"%1\">%2</font>".arg(Theme.text).arg(s.field)
                            return typed !== "" ? qsTr("Values of %1 · matching “%2”").arg(field).arg(typed)
                                                : qsTr("Values of %1").arg(field)
                        }
                    }
                    ListFrame {
                        Repeater {
                            model: Session.suggestions
                            delegate: SuggestionRow { }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.typing && Session.facets.count > 0
                    spacing: 8
                    Caption { text: qsTr("Other fields · tap to search by a field") }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: Session.facets
                            delegate: AbstractButton {
                                id: fieldChip
                                required property string field
                                required property int distinct
                                implicitHeight: 36
                                implicitWidth: fieldRow.implicitWidth + 24
                                Accessible.name: field
                                onClicked: root.addField(field)
                                background: Rectangle {
                                    radius: 18
                                    color: fieldChip.pressed ? Theme.hover : Theme.subtle
                                    border.width: 1
                                    border.color: Theme.border
                                }
                                contentItem: Item {
                                    Row {
                                        id: fieldRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: fieldChip.field
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.fontMd
                                            color: Theme.text
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: fieldChip.distinct
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.fontXs
                                            color: Theme.textMuted
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Recent queries (both views).
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: Session.history.length > 0
                    spacing: 4
                    Caption { text: root.typing ? qsTr("Recent queries") : qsTr("Recent") }
                    Repeater {
                        model: Session.history.slice(0, root.typing ? 3 : 8)
                        delegate: AbstractButton {
                            id: recent
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 44
                            Accessible.name: modelData
                            onClicked: { Session.searchText = modelData; root.search() }
                            background: Rectangle { radius: Theme.radiusMd; color: recent.pressed ? Theme.subtle : "transparent" }
                            contentItem: RowLayout {
                                spacing: 10
                                Icon { Layout.leftMargin: 4; name: "history"; size: 16; color: Theme.textMuted }
                                Text {
                                    Layout.fillWidth: true
                                    text: recent.modelData
                                    elide: Text.ElideRight
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontMd
                                    color: Theme.text
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.typing
                    textFormat: Text.StyledText
                    text: qsTr("Syntax: word · %1 · %2 · %3 to exclude · parts joined with AND")
                          .arg("<tt>key:value</tt>").arg("<tt>key:~regex</tt>").arg("<tt>-key:value</tt>")
                    wrapMode: Text.Wrap
                    lineHeight: 1.15
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
        }

        // Above the keyboard: the query symbols missing from the phone's first
        // keyboard screen, and Find.
        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0
            implicitHeight: 52
            color: Theme.surface
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4
                Repeater {
                    model: [":", "\"", "-", "~", "*"]
                    delegate: AbstractButton {
                        id: symbol
                        required property string modelData
                        implicitWidth: 44
                        implicitHeight: 44
                        focusPolicy: Qt.NoFocus
                        Accessible.name: modelData === "-" ? qsTr("Minus (exclude)") : modelData
                        onClicked: root.insert(modelData)
                        background: Rectangle { radius: Theme.radiusMd; color: symbol.pressed ? Theme.hover : Theme.subtle }
                        contentItem: Text {
                            text: symbol.modelData === "-" ? "−" : symbol.modelData
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXl
                            color: Theme.textStrong
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                AppButton {
                    implicitHeight: 44
                    variant: "primary"
                    text: qsTr("Find")
                    focusPolicy: Qt.NoFocus
                    onClicked: root.search()
                }
            }
        }
    }

    component Caption: Text {
        Layout.fillWidth: true
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.7
        font.capitalization: Font.AllUppercase
        color: Theme.textMuted
        elide: Text.ElideRight
    }

    // Rows in a rounded frame, separated by lines.
    component ListFrame: Rectangle {
        default property alias rows: rowsColumn.data
        Layout.fillWidth: true
        implicitHeight: rowsColumn.implicitHeight + 2
        radius: Theme.radiusLg
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderMuted
        clip: true
        Column {
            id: rowsColumn
            x: 1
            y: 1
            width: parent.width - 2
        }
    }

    component SuggestionRow: Item {
        id: suggestion
        required property int index
        required property string kind
        required property string field
        required property string value
        required property int count
        readonly property bool isValue: kind === "value"
        readonly property int maxCount: Session.suggestions.count > 0 ? Math.max(1, Session.suggestions.get(0).count) : 1
        width: parent ? parent.width : 0
        height: 52
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.borderMuted; visible: suggestion.index < Session.suggestions.count - 1 }
        AbstractButton {
            id: suggestionTap
            anchors.fill: parent
            Accessible.name: suggestion.isValue ? suggestion.value : suggestion.field + ":"
            // A field: "field:" goes into the query; a value: show only it.
            onClicked: {
                Session.applySuggestion(suggestion.index, false)
                if (suggestion.isValue) root.close()
                else { input.cursorPosition = Session.searchText.length; input.forceActiveFocus() }
            }
            background: Rectangle { color: suggestionTap.pressed ? Theme.subtle : "transparent" }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 4
            spacing: 4
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: suggestion.isValue ? suggestion.value : suggestion.field + ":"
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontLg
                    color: Theme.textStrong
                }
                RowLayout {
                    spacing: 8
                    Rectangle {
                        visible: suggestion.isValue
                        implicitWidth: Math.max(4, 160 * suggestion.count / suggestion.maxCount)
                        implicitHeight: 4
                        radius: 2
                        color: Theme.accent
                    }
                    Text {
                        text: suggestion.isValue ? suggestion.count.toLocaleString(Qt.locale(), "f", 0)
                                                 : qsTr("%n value(s)", "", suggestion.count)
                        font.family: suggestion.isValue ? Theme.mono : Theme.sans
                        font.pixelSize: Theme.fontXs
                        color: Theme.textMuted
                    }
                }
            }
            IconButton {
                visible: suggestion.isValue
                touch: true
                iconName: "plus"
                iconColor: Theme.accentText
                label: qsTr("Show only %1 = %2").arg(suggestion.field).arg(suggestion.value)
                onClicked: { Session.applySuggestion(suggestion.index, false); root.close() }
            }
            IconButton {
                visible: suggestion.isValue
                touch: true
                iconName: "minus"
                iconColor: Theme.dangerText
                label: qsTr("Exclude %1 = %2").arg(suggestion.field).arg(suggestion.value)
                onClicked: { Session.applySuggestion(suggestion.index, true); root.close() }
            }
        }
    }

    component SavedRow: Item {
        id: saved
        required property int index
        required property var model           // model.id: "id" cannot be a property name
        required property string name
        required property string environmentName
        required property string environmentColor
        required property string summary
        width: parent ? parent.width : 0
        height: 60
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.borderMuted; visible: saved.index < Session.savedQueries.count - 1 }
        AbstractButton {
            id: savedTap
            anchors.fill: parent
            Accessible.name: saved.name
            onClicked: { Session.runSavedQuery(saved.model.id); root.close() }
            background: Rectangle { color: savedTap.pressed ? Theme.subtle : "transparent" }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 4
            spacing: 4
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                RowLayout {
                    spacing: 8
                    Text {
                        Layout.maximumWidth: saved.width - 120
                        text: saved.name
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXl - 1
                        font.weight: Font.Medium
                        color: Theme.textStrong
                    }
                    Text {
                        visible: saved.environmentName !== ""
                        text: saved.environmentName
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.DemiBold
                        color: saved.environmentColor !== "" ? saved.environmentColor : Theme.textMuted
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: saved.summary
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }
            }
            IconButton {
                touch: true
                iconName: "more"
                label: qsTr("Actions with “%1”").arg(saved.name)
                onClicked: root.savedQueryMenuRequested(saved.model.id)
            }
        }
    }
}
