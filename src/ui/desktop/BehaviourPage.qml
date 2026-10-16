pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Loading, the start period, live tail; and a way back to the defaults.
Flickable {
    id: root

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

    clip: true
    contentHeight: column.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { }

    ColumnLayout {
        id: column
        x: 24
        y: 20
        width: root.width - 48
        spacing: 4

        SectionLabel { text: qsTr("Loading") }
        PrefRow {
            title: qsTr("Entries at a time")
            subtitle: qsTr("A search loads this many, and “Load more” adds as many again")
            SegmentedControl {
                accessibleName: qsTr("Entries at a time")
                model: [1000, 5000, 10000, 20000].map(n => ({ label: root.num(n), value: n }))
                value: Session.prefs.loadStep
                onActivated: v => Session.prefs.loadStep = v
            }
        }
        PrefRow {
            title: qsTr("Period at start")
            subtitle: qsTr("What the app shows when it opens")
            AppButton {
                id: rangeButton
                text: root.rangeLabel
                Accessible.name: qsTr("Period at start: %1").arg(root.rangeLabel)
                onClicked: rangeMenu.toggle()
                AppMenu {
                    id: rangeMenu
                    y: rangeButton.height + 4
                    x: rangeButton.width - width
                    Repeater {
                        model: root.ranges
                        delegate: AppMenuItem {
                            required property var modelData
                            text: modelData.label
                            checkedMark: Session.prefs.defaultRange === modelData.key
                            onTriggered: Session.prefs.defaultRange = modelData.key
                        }
                    }
                }
            }
        }

        SectionLabel { Layout.topMargin: 12; text: qsTr("Live tail") }
        PrefRow {
            title: qsTr("Ask for new lines every")
            subtitle: qsTr("More often is closer to real time and loads the server more")
            SegmentedControl {
                accessibleName: qsTr("Live tail interval")
                model: [{ label: qsTr("1 s"), value: 1000 }, { label: qsTr("2 s"), value: 2000 }, { label: qsTr("5 s"), value: 5000 }]
                value: Session.prefs.liveIntervalMs
                onActivated: v => Session.prefs.liveIntervalMs = v
            }
        }
        PrefRow {
            title: qsTr("Lines kept")
            subtitle: qsTr("Older lines leave the live view when there are more")
            SegmentedControl {
                accessibleName: qsTr("Live tail lines kept")
                model: [5000, 10000, 20000, 50000].map(n => ({ label: root.num(n), value: n }))
                value: Session.prefs.liveBuffer
                onActivated: v => Session.prefs.liveBuffer = v
            }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Live tail settings apply the next time it starts.")
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 20; implicitHeight: 1; color: Theme.borderMuted }
        PrefRow {
            title: qsTr("Default settings")
            subtitle: qsTr("Appearance, table and behaviour back as they were; connections, saved queries and history stay")
            AppButton {
                text: qsTr("Reset")
                onClicked: confirmReset.open()
            }
        }
    }

    ConfirmDialog {
        id: confirmReset
        title: qsTr("Reset the settings?")
        message: qsTr("Theme, table and behaviour return to their defaults.")
        confirmText: qsTr("Reset")
        onConfirmed: Session.prefs.reset()
    }
}
