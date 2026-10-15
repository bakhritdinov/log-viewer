import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Theme and how the feed looks: density, text size, lines of a message,
// tinted ERROR / WARN cards, pretty JSON. The same values as on the desktop.
SettingsScreen {
    id: root

    title: qsTr("Appearance")

    SectionLabel { text: qsTr("Theme") }
    SegmentedControl {
        Layout.fillWidth: true
        touch: true
        fill: true
        accessibleName: qsTr("Theme")
        model: [{ label: qsTr("Dark"), value: "dark" }, { label: qsTr("Light"), value: "light" },
                { label: qsTr("As in the system"), value: "system" }]
        value: Session.prefs.theme
        onActivated: v => Session.prefs.theme = v
    }

    SectionLabel { Layout.topMargin: 12; text: qsTr("Feed") }
    SettingRow {
        title: qsTr("Density")
        hint: qsTr("Compact fits more entries on the screen")
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Density")
            model: [{ label: qsTr("Compact"), value: "compact" }, { label: qsTr("Normal"), value: "normal" },
                    { label: qsTr("Roomy"), value: "comfortable" }]
            value: Session.prefs.density
            onActivated: v => Session.prefs.density = v
        }
    }
    SettingRow {
        title: qsTr("Log text size")
        hint: qsTr("The feed and the message in the details")
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Log text size")
            model: [11, 12, 13, 14, 15].map(n => ({ label: String(n), value: n }))
            value: Session.prefs.logFontSize
            onActivated: v => Session.prefs.logFontSize = v
        }
    }
    SettingRow {
        title: qsTr("Long messages")
        hint: qsTr("Lines of a message in a card")
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Long messages")
            model: [{ label: qsTr("1 line"), value: 1 }, { label: qsTr("2 lines"), value: 2 }, { label: qsTr("3 lines"), value: 3 }]
            value: Session.prefs.messageLines
            onActivated: v => Session.prefs.messageLines = v
        }
    }
    SettingRow {
        isSwitch: true
        title: qsTr("Tint ERROR and WARN")
        hint: qsTr("A coloured card background")
        switchChecked: Session.prefs.tintRows
        onSwitched: checked => Session.prefs.tintRows = checked
    }
    SettingRow {
        isSwitch: true
        title: qsTr("Pretty JSON in the details")
        hint: qsTr("Indents and colours")
        switchChecked: Session.prefs.prettyJson
        onSwitched: checked => Session.prefs.prettyJson = checked
    }
}
