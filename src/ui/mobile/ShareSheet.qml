import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// A link to the current selection: fixed or relative period, optionally the
// selected entry. No Grafana address or passwords in it. (A system "Send…"
// comes with the Android build; in the browser "Copy" is the main action.)
BottomSheet {
    id: root

    signal notice(string text, string actionText, var action)

    property bool fixedRange: true
    property bool includeSelection: true
    readonly property bool hasSelection: Session.selectedEntry.valid
    readonly property string link: opened ? Session.shareLink(fixedRange || Session.timeRangeAbsolute,
                                                              includeSelection && hasSelection) : ""

    title: qsTr("Share the selection")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.bottomMargin: 4
        spacing: 6
        visible: !Session.timeRangeAbsolute
        SectionLabel { text: qsTr("Period in the link") }
        Choice {
            checked: root.fixedRange
            onToggled: root.fixedRange = true
            text: qsTr("Freeze %1 – %2\na colleague sees exactly the same").arg(Session.absoluteFromText).arg(Session.absoluteToText)
        }
        Choice {
            checked: !root.fixedRange
            onToggled: root.fixedRange = false
            text: qsTr("Relative: “%1”").arg(Session.timeRangeLabel)
        }
    }

    AppCheckBox {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.minimumHeight: 48
        visible: root.hasSelection
        checked: root.includeSelection
        onToggled: root.includeSelection = checked
        font.pixelSize: Theme.fontLg
        text: qsTr("Highlight the entry %1").arg(Session.selectedEntry.dateTimeText)
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 6
        spacing: 10
        Icon { Layout.alignment: Qt.AlignTop; name: "lock"; size: 14; color: Theme.textMuted }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("No Grafana address or passwords. The recipient needs an environment named “%1”.").arg(Session.environmentName)
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            lineHeight: 1.2
            color: Theme.textMuted
        }
    }

    footer: AppButton {
        Layout.fillWidth: true
        touch: true
        variant: "primary"
        iconName: "copy"
        text: qsTr("Copy")
        onClicked: { clipboard.copy(root.link); root.close(); root.notice(qsTr("Link copied"), "", null) }
    }

    Clipboard { id: clipboard }

    component Choice: AppRadioButton {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        Layout.minimumHeight: 48
        font.pixelSize: Theme.fontLg
    }
}
