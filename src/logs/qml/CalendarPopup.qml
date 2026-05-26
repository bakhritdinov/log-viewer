import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: calendarPopup
    width: 280
    height: 420
    padding: 15
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property date selectedDate: new Date()
    property var targetField: null
    property bool isToField: false
    signal dateSelected(date date)

    function setTarget(field, isTo) {
        targetField = field
        isToField = isTo
        calendarPopup.open()
    }

    onAboutToShow: {
        if (targetField && targetField.text) {
            let d = new Date(targetField.text)
            if (!isNaN(d.getTime())) {
                // Use UTC methods so the time doesn't jump due to time zones.
                selectedDate = d
                let hh = d.getUTCHours()
                let mm = d.getUTCMinutes()
                hourField.text = (hh < 10 ? "0" : "") + hh
                minuteField.text = (mm < 10 ? "0" : "") + mm
                grid.year = d.getUTCFullYear()
                grid.month = d.getUTCMonth()
                return
            }
        }
        hourField.text = isToField ? "23" : "00"
        minuteField.text = isToField ? "59" : "00"
    }

    background: Rectangle {
        color: "#161b22"
        border.color: "#30363d"
        radius: 12
        border.width: 1
        layer.enabled: true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "❮"; flat: true
                onClicked: {
                    let d = new Date(grid.year, grid.month - 1, 1)
                    grid.year = d.getFullYear(); grid.month = d.getMonth()
                }
                contentItem: Text { text: parent.text; color: "#8b949e"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter }
            }
            Text {
                text: Qt.formatDateTime(new Date(grid.year, grid.month, 1), "MMMM yyyy")
                color: "#c9d1d9"; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            }
            Button {
                text: "❯"; flat: true
                onClicked: {
                    let d = new Date(grid.year, grid.month + 1, 1)
                    grid.year = d.getFullYear(); grid.month = d.getMonth()
                }
                contentItem: Text { text: parent.text; color: "#8b949e"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter }
            }
        }

        // Hand-rolled day-of-week row (Mon-first) and 6x7 date grid — avoids
        // MonthGrid/DayOfWeekRow which aren't available in Qt 6.2 (Ubuntu 22.04).
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                delegate: Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: "#8b949e"; font.pixelSize: 11; font.bold: true
                }
            }
        }

        Item {
            id: grid
            property int year: new Date().getFullYear()
            property int month: new Date().getMonth()
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property var cells: {
                // 42 cells starting from the Monday on/before the 1st of the month.
                let first = new Date(grid.year, grid.month, 1)
                let offset = (first.getDay() + 6) % 7
                let start = new Date(grid.year, grid.month, 1 - offset)
                let result = []
                for (let i = 0; i < 42; i++) {
                    result.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
                }
                return result
            }

            GridLayout {
                anchors.fill: parent
                columns: 7
                rowSpacing: 2
                columnSpacing: 2
                Repeater {
                    model: grid.cells
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitWidth: 35
                        implicitHeight: 35
                        radius: 6
                        readonly property date cellDate: modelData
                        readonly property bool sameMonth: cellDate.getMonth() === grid.month
                        readonly property bool isToday: {
                            let t = new Date()
                            return cellDate.getFullYear() === t.getFullYear() &&
                                   cellDate.getMonth() === t.getMonth() &&
                                   cellDate.getDate() === t.getDate()
                        }
                        readonly property bool isSelected: cellDate.toDateString() === selectedDate.toDateString()
                        color: isSelected ? "#238636" :
                               (mArea.containsMouse ? "#21262d" : "transparent")
                        border.color: isToday ? "#58a6ff" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: cellDate.getDate()
                            color: sameMonth ? (isSelected ? "#ffffff" : "#c9d1d9") : "#484f58"
                            font.pixelSize: 12
                            font.bold: isToday
                        }
                        MouseArea {
                            id: mArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { selectedDate = cellDate }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Label { text: "UTC:"; color: "#8b949e"; font.bold: true; font.pixelSize: 11 }
            TextField {
                id: hourField; text: "00"; Layout.preferredWidth: 35
                horizontalAlignment: TextInput.AlignHCenter; color: "#c9d1d9"; font.pixelSize: 12
                background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 4; implicitHeight: 26 }
            }
            Text { text: ":"; color: "#8b949e" }
            TextField {
                id: minuteField; text: "00"; Layout.preferredWidth: 35
                horizontalAlignment: TextInput.AlignHCenter; color: "#c9d1d9"; font.pixelSize: 12
                background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 4; implicitHeight: 26 }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Apply"
                onClicked: {
                    let h = parseInt(hourField.text) || 0
                    let m = parseInt(minuteField.text) || 0
                    let s = isToField ? 59 : 0
                    
                    // Build the date in UTC.
                    let finalDate = new Date(Date.UTC(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate(), h, m, s))
                    let formatted = finalDate.toISOString().split(".")[0] + "Z"
                    
                    if (targetField) {
                        targetField.text = formatted
                        window.refreshLogs(window.searchHeader.searchText)
                    }
                    calendarPopup.close()
                }
                contentItem: Text { text: parent.text; color: "#ffffff"; font.bold: true; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
                background: Rectangle { color: "#238636"; radius: 6; implicitWidth: 70; implicitHeight: 32 }
            }
        }
    }
}
