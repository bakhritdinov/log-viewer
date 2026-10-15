pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// Month grid for the custom period: highlights `selected`, reports a picked day.
ColumnLayout {
    id: root

    property date selected: new Date()
    property int month: selected.getMonth()
    property int year: selected.getFullYear()

    signal picked(date day)

    function shiftMonth(delta) {
        const d = new Date(year, month + delta, 1)
        month = d.getMonth()
        year = d.getFullYear()
    }

    spacing: 8
    onSelectedChanged: { month = selected.getMonth(); year = selected.getFullYear() }

    RowLayout {
        Layout.fillWidth: true
        IconButton { iconName: "chevronLeft"; label: qsTr("Previous month"); onClicked: root.shiftMonth(-1) }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: {
                const name = Qt.locale().standaloneMonthName(root.month, Locale.LongFormat)
                return name.charAt(0).toUpperCase() + name.slice(1) + " " + root.year
            }
            font.family: Theme.sans
            font.pixelSize: Theme.fontMd
            font.weight: Font.DemiBold
            color: Theme.textStrong
        }
        IconButton { iconName: "chevronRight"; label: qsTr("Next month"); onClicked: root.shiftMonth(1) }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: Qt.locale()
        delegate: Text {
            id: weekday
            required property string shortName
            text: weekday.shortName
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.sans
            font.pixelSize: Theme.fontXs
            color: Theme.textMuted
        }
    }

    MonthGrid {
        id: grid
        Layout.fillWidth: true
        month: root.month
        year: root.year
        locale: Qt.locale()
        spacing: 2
        delegate: AbstractButton {
            id: day
            required property var model
            readonly property bool inMonth: day.model.month === grid.month
            readonly property bool isSelected: day.model.date.getFullYear() === root.selected.getFullYear()
                                               && day.model.date.getMonth() === root.selected.getMonth()
                                               && day.model.date.getDate() === root.selected.getDate()
            implicitHeight: 28
            enabled: inMonth
            focusPolicy: Qt.NoFocus
            Accessible.name: day.model.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            Accessible.role: Accessible.Button
            onClicked: root.picked(day.model.date)
            background: Rectangle {
                radius: Theme.radiusMd
                color: day.isSelected ? Theme.accentStrong : (day.hovered && day.inMonth ? Theme.subtle : "transparent")
            }
            contentItem: Text {
                text: day.inMonth ? day.model.day : ""
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                color: day.isSelected ? Theme.textOnAccent : (day.model.today ? Theme.accent : Theme.text)
            }
        }
    }
}
