pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Loading (entries at a time, the period at start), live tail (how often,
// how many lines) and back to the defaults.
SettingsScreen {
    id: root

    signal notice(string text)

    readonly property var ranges: [
        { key: "last", label: qsTr("The last one used") },
        { key: "15m", label: qsTr("Last 15 minutes") },
        { key: "1h", label: qsTr("Last 1 hour") },
        { key: "6h", label: qsTr("Last 6 hours") },
        { key: "1d", label: qsTr("Last 24 hours") },
        { key: "today", label: qsTr("Today") },
    ]
    readonly property string rangeLabel: {
        for (const r of ranges) if (r.key === Session.prefs.defaultRange) return r.label
        return ranges[0].label
    }
    function num(n) { return n.toLocaleString(Qt.locale(), "f", 0) }

    title: qsTr("Behaviour")

    SectionLabel { text: qsTr("Loading") }
    SettingRow {
        title: qsTr("Entries at a time")
        hint: qsTr("A search and “Load more”")
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Entries at a time")
            model: [1000, 5000, 10000, 20000].map(n => ({ label: root.num(n), value: n }))
            value: Session.prefs.loadStep
            onActivated: v => Session.prefs.loadStep = v
        }
    }
    SettingRow {
        title: qsTr("Period at start")
        hint: root.rangeLabel
        Accessible.name: qsTr("Period at start: %1").arg(root.rangeLabel)
        onClicked: rangeSheet.open()
    }

    SectionLabel { Layout.topMargin: 12; text: qsTr("Live tail") }
    SettingRow {
        title: qsTr("New lines every")
        hint: qsTr("Less often means less traffic and battery")
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Live tail interval")
            model: [{ label: qsTr("1 s"), value: 1000 }, { label: qsTr("2 s"), value: 2000 }, { label: qsTr("5 s"), value: 5000 }]
            value: Session.prefs.liveIntervalMs
            onActivated: v => Session.prefs.liveIntervalMs = v
        }
    }
    SettingRow {
        title: qsTr("Lines kept")
        hint: qsTr("The oldest leave the feed")
        SegmentedControl {
            Layout.fillWidth: true
            touch: true
            fill: true
            accessibleName: qsTr("Live tail lines kept")
            model: [5000, 10000, 20000, 50000].map(n => ({ label: root.num(n), value: n }))
            value: Session.prefs.liveBuffer
            onActivated: v => Session.prefs.liveBuffer = v
        }
    }
    Text {
        Layout.fillWidth: true
        text: qsTr("Applies the next time live tail starts.")
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: Theme.fontSm
        color: Theme.textMuted
    }

    AppButton {
        Layout.fillWidth: true
        Layout.topMargin: 16
        touch: true
        text: qsTr("Back to the default settings")
        onClicked: resetDialog.open()
    }

    // The period at start: a tap picks it and closes the sheet.
    BottomSheet {
        id: rangeSheet
        title: qsTr("Period at start")
        Repeater {
            model: root.ranges
            delegate: AbstractButton {
                id: range
                required property var modelData
                readonly property bool current: Session.prefs.defaultRange === modelData.key
                Layout.fillWidth: true
                implicitHeight: 48
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.checked: current
                onClicked: { Session.prefs.defaultRange = modelData.key; rangeSheet.close() }
                background: Rectangle { color: range.pressed ? Theme.subtle : "transparent" }
                contentItem: RowLayout {
                    spacing: 12
                    Icon { Layout.leftMargin: 18; name: "check"; size: 18; color: Theme.accentText; opacity: range.current ? 1 : 0 }
                    Text {
                        Layout.fillWidth: true
                        text: range.modelData.label
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontLg + 1
                        font.weight: range.current ? Font.DemiBold : Font.Normal
                        color: Theme.textStrong
                    }
                }
            }
        }
        Item { implicitHeight: 12 }
    }

    ConfirmDialog {
        id: resetDialog
        title: qsTr("Reset the settings?")
        message: qsTr("Appearance, feed and behaviour return to their defaults. Environments, saved queries and history stay.")
        confirmText: qsTr("Reset")
        destructive: false
        onConfirmed: { Session.prefs.reset(); root.notice(qsTr("Settings reset")) }
    }
}
