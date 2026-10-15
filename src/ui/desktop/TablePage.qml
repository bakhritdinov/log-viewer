pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The log table: how time is written and which columns are shown.
Flickable {
    id: root

    function addColumn() {
        const field = columnField.text.trim()
        if (field === "") return
        Session.prefs.addColumn(field)
        columnField.text = ""
    }

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

        SectionLabel { text: qsTr("Time") }
        PrefRow {
            title: qsTr("Time format")
            subtitle: qsTr("In the table; the details always show the full date and milliseconds")
            SegmentedControl {
                accessibleName: qsTr("Time format")
                model: [{ label: "20:38:42.847", value: "ms" }, { label: "20:38:42", value: "s" },
                        { label: qsTr("15 Oct 20:38:42"), value: "date" }]
                value: Session.prefs.timeFormat
                onActivated: v => Session.prefs.timeFormat = v
            }
        }
        PrefRow {
            title: qsTr("Show time in UTC")
            subtitle: qsTr("Handy when comparing with server logs; the period is still picked in local time")
            AppSwitch {
                checked: Session.prefs.utc
                onToggled: Session.prefs.utc = checked
                Accessible.name: qsTr("Show time in UTC")
            }
        }

        SectionLabel { Layout.topMargin: 12; text: qsTr("Columns") }
        PrefRow {
            title: qsTr("Level")
            AppSwitch {
                checked: Session.prefs.showLevel
                onToggled: Session.prefs.showLevel = checked
                Accessible.name: qsTr("Level column")
            }
        }
        PrefRow {
            title: qsTr("Service")
            subtitle: qsTr("Hidden anyway when the table is narrow")
            AppSwitch {
                checked: Session.prefs.showService
                onToggled: Session.prefs.showService = checked
                Accessible.name: qsTr("Service column")
            }
        }
        PrefRow {
            title: qsTr("Columns from fields")
            subtitle: qsTr("Any field of an entry as a column before the message, e.g. trace_id or context.client_id. In the details, the column button next to a field does the same.")
        }
        Flow {
            Layout.fillWidth: true
            visible: Session.prefs.extraColumns.length > 0
            spacing: 6
            Repeater {
                model: Session.prefs.extraColumns
                delegate: FilterChip {
                    required property string modelData
                    text: modelData
                    onRemoveRequested: Session.prefs.removeColumn(modelData)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            AppTextField {
                id: columnField
                Layout.fillWidth: true
                implicitHeight: 32
                placeholderText: qsTr("Field name")
                Accessible.name: qsTr("Field for a new column")
                onAccepted: root.addColumn()
            }
            AppButton {
                implicitHeight: 32
                iconName: "plus"
                text: qsTr("Add column")
                enabled: columnField.text.trim() !== ""
                onClicked: root.addColumn()
            }
        }
    }
}
