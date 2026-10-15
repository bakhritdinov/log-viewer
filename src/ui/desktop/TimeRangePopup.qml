import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Period picker: quick presets on the left, a custom period with a calendar
// on the right.
Popup {
    id: root

    function pickDay(day) {
        if (form.activeField === 0) form.fromText = Session.boundOnDay(form.fromText, day, false)
        else form.toText = Session.boundOnDay(form.toText, day, true)
    }

    width: 620
    padding: 0
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onOpened: {
        form.fromText = Session.absoluteFromText
        form.toText = Session.absoluteToText
        form.activeField = 0
    }

    background: Surface { elevated: true; radius: Theme.radiusLg + 2 }

    contentItem: RowLayout {
        spacing: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Choose the period")

        ColumnLayout {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            Layout.margins: 8
            Layout.topMargin: 12
            spacing: 6
            SectionLabel { Layout.leftMargin: 8; text: qsTr("Quick") }
            TimePresetGrid {
                Layout.fillWidth: true
                currentKey: Session.timeRangeKey
                onPicked: key => { Session.setPreset(key); root.close() }
            }
            Item { Layout.fillHeight: true }
        }
        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.borderMuted }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.topMargin: 14
            spacing: 12
            SectionLabel { text: qsTr("Custom period") }
            AbsoluteRangeForm {
                id: form
                Layout.fillWidth: true
                errorText: Session.rangeError
                cancellable: true
                timeZoneNote: qsTr("Time zone: local (%1)").arg(Session.timeZoneLabel)
                onApplyRequested: (from, to) => { if (Session.setAbsoluteRange(from, to)) root.close() }
                onCancelRequested: root.close()

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: calendar.implicitHeight + 20
                    radius: Theme.radiusLg
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.borderMuted
                    CalendarView {
                        id: calendar
                        anchors.fill: parent
                        anchors.margins: 10
                        selected: Session.boundDate(form.activeField === 0 ? form.fromText : form.toText)
                        onPicked: day => root.pickDay(day)
                    }
                }
            }
        }
    }
}
