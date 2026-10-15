pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import LogViewer.Ui

// Month grid for the custom period: the range between `rangeFrom` and `rangeTo`
// as a band with filled ends, today outlined; days after today cannot be picked.
ColumnLayout {
    id: root

    property date selected: new Date()
    property int month: selected.getMonth()
    property int year: selected.getFullYear()
    property date rangeFrom
    property date rangeTo

    function dayNumber(d) { return isNaN(d) ? NaN : Math.floor(new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() / 86400000) }
    readonly property real today: dayNumber(new Date())
    readonly property real fromDay: dayNumber(rangeFrom)
    readonly property real toDay: dayNumber(rangeTo)
    readonly property bool atCurrentMonth: year > new Date().getFullYear()
                                           || (year === new Date().getFullYear() && month >= new Date().getMonth())

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
        IconButton { iconName: "chevronRight"; label: qsTr("Next month"); enabled: !root.atCurrentMonth; onClicked: root.shiftMonth(1) }
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
            readonly property real number: root.dayNumber(day.model.date)
            readonly property bool isSelected: number === root.dayNumber(root.selected)
            readonly property bool isEnd: number === root.fromDay || number === root.toDay
            readonly property bool inRange: number > root.fromDay && number < root.toDay
            readonly property bool future: number > root.today
            implicitHeight: 28
            enabled: inMonth && !future
            focusPolicy: Qt.NoFocus
            Accessible.name: day.model.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            Accessible.role: Accessible.Button
            onClicked: root.picked(day.model.date)
            background: Rectangle {
                radius: day.inRange ? 0 : Theme.radiusMd
                color: !day.inMonth ? "transparent"
                     : day.isSelected || day.isEnd ? Theme.accentStrong
                     : day.inRange ? Theme.tint(Theme.accentStrong, 0.2)
                     : (day.hovered && day.enabled ? Theme.subtle : "transparent")
                border.width: day.inMonth && day.model.today && !day.isEnd && !day.isSelected ? 1 : 0
                border.color: Theme.textMuted
            }
            contentItem: Text {
                text: day.inMonth ? day.model.day : ""
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                color: day.isSelected || day.isEnd ? Theme.textOnAccent
                     : day.future ? Theme.textDisabled
                     : (day.model.today ? Theme.accent : Theme.text)
            }
        }
    }
}
