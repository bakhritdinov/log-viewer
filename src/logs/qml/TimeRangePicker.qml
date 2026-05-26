import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Item {
    id: root

    // ── Public API — same shape SearchHeader/AppContent already consume ────
    property string timeRange: "1h"
    property string customFrom: ""
    property string customTo: ""
    property string display: ""

    signal changed()

    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight

    Component.onCompleted: if (display === "") display = _labelFor(timeRange)

    function _labelFor(range) {
        if (range === "Custom") return (root.customFrom || "?") + " → " + (root.customTo || "?")
        let m = range.match(/(\d+)([smhd])/)
        if (!m) return range
        let n = parseInt(m[1])
        switch (m[2]) {
            case "s": return n < 60 ? `Last ${n}s` : `Last ${Math.round(n/60)} min`
            case "m": return `Last ${n} min`
            case "h": return n === 1 ? "Last 1 hour" : `Last ${n} hours`
            case "d": return n === 1 ? "Last 1 day"  : `Last ${n} days`
        }
        return range
    }

    function applyPreset(label, value) {
        timeRange = value
        customFrom = ""
        customTo = ""
        display = label
        changed()
        popup.close()
    }

    function applyToday() {
        const now = new Date()
        const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const seconds = Math.max(60, Math.floor((now - midnight) / 1000))
        timeRange = `${seconds}s`
        customFrom = ""
        customTo = ""
        display = "Today"
        changed()
        popup.close()
    }

    function applyAbsolute() {
        if (!fromField.text || !toField.text) return
        timeRange = "Custom"
        customFrom = fromField.text
        customTo = toField.text
        display = `${fromField.text} → ${toField.text}`
        changed()
        popup.close()
    }

    // Programmatic external update (e.g. restoring state). Refreshes display
    // and emits changed() so listeners react as if the user picked a value.
    function applyExternal(tr, cf, ct) {
        // "Custom" with no dates → fall back to 1h, otherwise chip shows "? → ?".
        if (tr === "Custom" && (!cf || !ct)) {
            tr = "1h"
            cf = ""
            ct = ""
        }
        // For any preset, clear custom dates so popup From/To fields don't
        // keep showing stale values from a previous Custom session.
        if (tr !== "Custom") {
            cf = ""
            ct = ""
        }
        timeRange = tr
        customFrom = cf || ""
        customTo = ct || ""
        // CalendarPopup writes targetField.text directly, which breaks the
        // `text: root.customFrom` binding on AbsoluteField. A forced reassign
        // here keeps the visible TextField in sync after such writes.
        if (fromField) fromField.text = customFrom
        if (toField)   toField.text   = customTo
        if (tr === "Custom") {
            display = customFrom + " → " + customTo
        } else {
            display = _labelFor(tr)
        }
        changed()
    }

    // ── Trigger button ────────────────────────────────────────────────────
    SecondaryButton {
        id: trigger
        text: "🕐  " + root.display + "  ▾"
        font.pixelSize: Theme.fsSm
        Layout.preferredHeight: Theme.hButton + 4
        active: popup.opened
        onClicked: popup.open()
    }

    // ── Popup ─────────────────────────────────────────────────────────────
    Popup {
        id: popup
        x: 0
        y: trigger.height + 4
        width: 520
        height: layout.implicitHeight + Theme.sp4 * 2
        modal: false
        focus: true
        padding: 0

        background: Rectangle {
            color: Theme.bgRaised
            border.color: Theme.border
            border.width: 1
            radius: Theme.rLg
        }

        contentItem: RowLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.sp4
            spacing: Theme.sp4

            // ── Quick presets column ──────────────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 220
                Layout.alignment: Qt.AlignTop
                spacing: Theme.sp2

                Text {
                    text: "QUICK"
                    color: Theme.textMuted
                    font.bold: true
                    font.pixelSize: Theme.fsXs
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
                }

                GridLayout {
                    columns: 2
                    columnSpacing: Theme.sp1
                    rowSpacing: Theme.sp1
                    Layout.fillWidth: true

                    Repeater {
                        model: [
                            ["Last 5 min",   "5m"],
                            ["Last 15 min",  "15m"],
                            ["Last 30 min",  "30m"],
                            ["Last 1 hour",  "1h"],
                            ["Last 3 hours", "3h"],
                            ["Last 6 hours", "6h"],
                            ["Last 12 hours","12h"],
                            ["Last 24 hours","24h"],
                            ["Last 2 days",  "2d"],
                            ["Last 7 days",  "7d"]
                        ]
                        delegate: PresetItem {
                            Layout.fillWidth: true
                            label: modelData[0]
                            value: modelData[1]
                            active: root.timeRange === modelData[1] && root.display === modelData[0]
                            onClicked: root.applyPreset(label, value)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderMuted }

                PresetItem {
                    Layout.fillWidth: true
                    label: "Today"
                    active: root.display === "Today"
                    onClicked: root.applyToday()
                }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.borderMuted }

            // ── Absolute column ───────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.sp2

                Text {
                    text: "ABSOLUTE"
                    color: Theme.textMuted
                    font.bold: true
                    font.pixelSize: Theme.fsXs
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
                }

                Text { text: "From"; color: Theme.textMuted; font.pixelSize: Theme.fsXs }
                AbsoluteField {
                    id: fromField
                    Layout.fillWidth: true
                    placeholder: "YYYY-MM-DD HH:MM"
                    text: root.customFrom
                    onCalendarRequested: calendarPopup.setTarget(internalText, false)
                }

                Text { text: "To"; color: Theme.textMuted; font.pixelSize: Theme.fsXs; topPadding: Theme.sp1 }
                AbsoluteField {
                    id: toField
                    Layout.fillWidth: true
                    placeholder: "YYYY-MM-DD HH:MM"
                    text: root.customTo
                    onCalendarRequested: calendarPopup.setTarget(internalText, true)
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: Theme.sp2 }

                PrimaryButton {
                    Layout.alignment: Qt.AlignRight
                    text: "Apply"
                    enabled: fromField.text !== "" && toField.text !== ""
                    onClicked: root.applyAbsolute()
                }
            }
        }
    }

    CalendarPopup { id: calendarPopup }

    component PresetItem : Rectangle {
        property string label: ""
        property string value: ""
        property bool   active: false
        signal clicked()

        implicitHeight: 28
        radius: Theme.rSm
        color: active ? Theme.successDim
             : presetMouse.containsMouse ? Theme.bgSubtle
             : "transparent"
        border.color: active ? Theme.success : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.dFast } }

        Text {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp3
            verticalAlignment: Text.AlignVCenter
            text: parent.label
            color: parent.active ? Theme.textOnAccent : Theme.text
            font.pixelSize: Theme.fsSm
        }
        MouseArea {
            id: presetMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component AbsoluteField : Rectangle {
        property alias text: internalText.text
        property string placeholder: ""
        property alias internalText: internalText
        signal calendarRequested()

        implicitHeight: Theme.hInput
        color: Theme.bgInput
        border.color: Theme.border
        border.width: 1
        radius: Theme.rMd

        TextField {
            id: internalText
            anchors.left: parent.left; anchors.leftMargin: Theme.sp3
            anchors.right: calBtn.left
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: parent.placeholder
            placeholderTextColor: Theme.textDim
            color: Theme.text
            font.pixelSize: Theme.fsSm
            background: null
            readOnly: true
        }
        IconButton {
            id: calBtn
            anchors.right: parent.right; anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            text: "📅"
            tooltipText: "Pick date"
            pixel: Theme.fsSm
            boxSize: 28
            onClicked: parent.calendarRequested()
        }
    }
}
