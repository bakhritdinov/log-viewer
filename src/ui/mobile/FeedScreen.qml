pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// What a card shows: the time format (and UTC), level and service, and fields
// as a line under the message (the desktop's columns).
SettingsScreen {
    id: root

    title: qsTr("Feed")

    function addField() {
        const name = fieldInput.text.trim()
        if (name === "") return
        Session.prefs.addColumn(name)
        fieldInput.text = ""
    }

    SectionLabel { text: qsTr("Time") }
    SegmentedControl {
        Layout.fillWidth: true
        touch: true
        fill: true
        accessibleName: qsTr("Time format")
        model: [{ label: "20:38:42.847", value: "ms" }, { label: "20:38:42", value: "s" },
                { label: qsTr("15 Oct 20:38"), value: "date" }]
        value: Session.prefs.timeFormat
        onActivated: v => Session.prefs.timeFormat = v
    }
    SettingRow {
        isSwitch: true
        title: qsTr("Time in UTC")
        hint: qsTr("The period is still picked in local time")
        switchChecked: Session.prefs.utc
        onSwitched: checked => Session.prefs.utc = checked
    }

    SectionLabel { Layout.topMargin: 12; text: qsTr("In the card") }
    SettingRow {
        isSwitch: true
        title: qsTr("Level")
        switchChecked: Session.prefs.showLevel
        onSwitched: checked => Session.prefs.showLevel = checked
    }
    SettingRow {
        isSwitch: true
        title: qsTr("Service")
        switchChecked: Session.prefs.showService
        onSwitched: checked => Session.prefs.showService = checked
    }

    SectionLabel { Layout.topMargin: 12; text: qsTr("Fields in the card") }
    Text {
        Layout.fillWidth: true
        text: qsTr("Values of fields as a line under the message, e.g. trace_id. In the details, a long press on a field offers the same.")
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }
    Flow {
        Layout.fillWidth: true
        visible: Session.prefs.extraColumns.length > 0
        spacing: 6
        Repeater {
            model: Session.prefs.extraColumns
            delegate: FilterChip {
                required property string modelData
                touch: true
                text: modelData
                onRemoveRequested: Session.prefs.removeColumn(modelData)
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        AppTextField {
            id: fieldInput
            Layout.fillWidth: true
            touch: true
            mono: true
            font.pixelSize: 16
            placeholderText: qsTr("Field name")
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            Accessible.name: qsTr("Field for the card")
            onAccepted: root.addField()
        }
        IconButton {
            touch: true
            iconName: "plus"
            label: qsTr("Add the field")
            enabled: fieldInput.text.trim() !== ""
            onClicked: root.addField()
        }
    }
}
