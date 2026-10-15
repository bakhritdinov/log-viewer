import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// The period: a preset applies at once and closes the sheet (the current one
// is green); a custom period is applied with its button, and a wrong one keeps
// the sheet open with the reason.
BottomSheet {
    id: root

    objectName: "timeSheet"
    title: qsTr("Period")
    onAboutToShow: {
        form.fromText = Session.absoluteFromText
        form.toText = Session.absoluteToText
    }

    TimePresetGrid {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        touch: true
        currentKey: Session.timeRangeKey
        onPicked: key => { Session.setPreset(key); root.close() }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.margins: 16
        implicitHeight: 1
        color: Theme.border
    }
    SectionLabel {
        Layout.leftMargin: 16
        Layout.bottomMargin: 10
        text: qsTr("Custom period")
    }
    AbsoluteRangeForm {
        id: form
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.bottomMargin: 16
        touch: true
        errorText: Session.rangeError
        timeZoneNote: qsTr("Local time (%1).").arg(Session.timeZoneLabel)
        onApplyRequested: (from, to) => { if (Session.setAbsoluteRange(from, to)) root.close() }
    }
}
