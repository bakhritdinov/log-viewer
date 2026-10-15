import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Fixed period: two "YYYY-MM-DD HH:MM" fields and Apply. Validation lives in
// the view-model; its message comes back through `errorText`.
ColumnLayout {
    id: root

    property alias fromText: fromField.text
    property alias toText: toField.text
    property string errorText
    property bool touch: false
    property string timeZoneNote
    property bool cancellable: false
    // 0 — "from", 1 — "to": the field a picked calendar day goes into.
    property int activeField: 0
    // Extra content between the fields and the buttons (e.g. a calendar).
    default property alias extra: extraSlot.data

    signal applyRequested(string from, string to)
    signal cancelRequested()

    spacing: 10

    GridLayout {
        Layout.fillWidth: true
        columns: root.touch ? 1 : 2
        columnSpacing: 10
        rowSpacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                text: qsTr("From")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            AppTextField {
                id: fromField
                Layout.fillWidth: true
                touch: root.touch
                mono: true
                invalid: root.errorText !== ""
                placeholderText: qsTr("YYYY-MM-DD HH:MM")
                inputMethodHints: Qt.ImhPreferNumbers
                Accessible.name: qsTr("Start of the period")
                onActiveFocusChanged: if (activeFocus) root.activeField = 0
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                text: qsTr("To")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            AppTextField {
                id: toField
                Layout.fillWidth: true
                touch: root.touch
                mono: true
                invalid: root.errorText !== ""
                placeholderText: qsTr("YYYY-MM-DD HH:MM")
                inputMethodHints: Qt.ImhPreferNumbers
                Accessible.name: qsTr("End of the period")
                onActiveFocusChanged: if (activeFocus) root.activeField = 1
                onAccepted: root.applyRequested(fromField.text, toField.text)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.errorText !== ""
        text: root.errorText
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.dangerText
        Accessible.role: Accessible.AlertMessage
    }

    ColumnLayout {
        id: extraSlot
        Layout.fillWidth: true
        visible: children.length > 0
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.fillWidth: true
            text: root.timeZoneNote
            wrapMode: Text.Wrap
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
        AppButton {
            visible: root.cancellable
            touch: root.touch
            text: qsTr("Cancel")
            onClicked: root.cancelRequested()
        }
        AppButton {
            variant: "primary"
            touch: root.touch
            text: qsTr("Apply")
            Layout.fillWidth: root.touch
            onClicked: root.applyRequested(fromField.text, toField.text)
        }
    }
}
