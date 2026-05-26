import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: chart

    property var buckets: []
    property int bucketMs: 60000

    property bool collapsed: false
    property int chartHeight: 140
    readonly property int collapsedHeight: 28
    readonly property int minChartHeight: 80
    readonly property int maxChartHeight: 360

    property bool filterActive: false

    // 0 = Auto — AppContent computes from timeRangeSec.
    property int manualBucketMs: 0
    signal bucketSizeChanged()
    onManualBucketMsChanged: bucketSizeChanged()

    property int hoverIndex: -1
    property string hoverLevel: ""
    property real hoverCenterX: 0

    readonly property var totals: {
        let t = { ERROR: 0, WARN: 0 }
        for (let i = 0; i < buckets.length; i++) {
            let b = buckets[i]
            t.ERROR += (b.ERROR || 0)
            t.WARN  += (b.WARN  || 0)
        }
        return t
    }
    readonly property int grandTotal: totals.ERROR + totals.WARN

    signal bucketClicked(real fromMs, real toMs, string level)
    signal resetRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: collapsed ? collapsedHeight : chartHeight

    color: Theme.bgRaised
    border.color: Theme.border
    border.width: 1
    radius: Theme.rMd

    Item {
        id: collapsedStrip
        anchors.fill: parent
        visible: chart.collapsed

        Row {
            anchors.left: parent.left
            anchors.right: expandBtn.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.sp3
            spacing: 6

            Text {
                text: "▾"
                color: Theme.textMuted
                font.pixelSize: Theme.fsXs
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Distribution (collapsed)"
                color: Theme.textMuted
                font.pixelSize: Theme.fsXs
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            id: expandBtn
            width: 92
            height: 20
            radius: 4
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Theme.sp3
            color: expandArea.containsMouse ? Theme.bgHover : Theme.bgSubtle
            border.color: Theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "▾ Expand"
                color: Theme.text
                font.pixelSize: Theme.fsXs
                font.bold: true
            }

            MouseArea {
                id: expandArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chart.collapsed = false
            }
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onDoubleClicked: chart.collapsed = false
        }
    }

    RowLayout {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.sp3
        height: 18
        spacing: Theme.sp3
        visible: !chart.collapsed

        Row {
            spacing: 6
            Text {
                text: "Distribution"
                color: Theme.textMuted
                font.pixelSize: Theme.fsXs
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: chart.grandTotal > 0
                text: "· " + chart.grandTotal
                color: Theme.text
                font.pixelSize: Theme.fsXs
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            spacing: 1
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [
                    { label: "Auto", ms: 0 },
                    { label: "1m",   ms: 60000 },
                    { label: "5m",   ms: 300000 },
                    { label: "15m",  ms: 900000 },
                    { label: "1h",   ms: 3600000 }
                ]
                delegate: Rectangle {
                    width: pickerText.implicitWidth + 12
                    height: 18
                    radius: 3
                    readonly property bool isActive: chart.manualBucketMs === modelData.ms
                    color: isActive ? Theme.accent
                         : pickerArea.containsMouse ? Theme.bgHover
                         : Theme.bgSubtle
                    border.color: isActive ? Theme.accent : Theme.border
                    border.width: 1

                    Text {
                        id: pickerText
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.isActive ? Theme.textOnAccent : Theme.text
                        font.pixelSize: Theme.fsXs
                        font.bold: parent.isActive
                    }
                    MouseArea {
                        id: pickerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: chart.manualBucketMs = modelData.ms
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        Repeater {
            model: [
                { name: "ERROR", color: Theme.levelError, count: chart.totals.ERROR },
                { name: "WARN",  color: Theme.levelWarn,  count: chart.totals.WARN  }
            ]
            delegate: Row {
                spacing: 4
                visible: modelData.count > 0
                Rectangle {
                    width: 8
                    height: 8
                    radius: 2
                    color: modelData.color
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: modelData.name + " " + modelData.count
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsXs
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 130
            Layout.preferredHeight: 22
            visible: chart.filterActive
            radius: 4
            color: resetArea.containsMouse ? Theme.accent : Theme.bgSubtle
            border.color: resetArea.containsMouse ? Theme.accent : Theme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.dFast } }

            Row {
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "↺"
                    color: resetArea.containsMouse ? Theme.textOnAccent : Theme.accent
                    font.pixelSize: Theme.fsMd
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Reset filter"
                    color: resetArea.containsMouse ? Theme.textOnAccent : Theme.text
                    font.pixelSize: Theme.fsXs
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chart.resetRequested()
            }
        }

        Rectangle {
            Layout.preferredWidth: 78
            Layout.preferredHeight: 20
            radius: 4
            color: collapseArea.containsMouse ? Theme.bgHover : Theme.bgSubtle
            border.color: collapseArea.containsMouse ? Theme.accent : Theme.border
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "▴"
                    color: Theme.text
                    font.pixelSize: Theme.fsXs
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Collapse"
                    color: Theme.text
                    font.pixelSize: Theme.fsXs
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: collapseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chart.collapsed = true
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !chart.collapsed && chart.buckets.length === 0
        text: "Run a search to see the distribution"
        color: Theme.textDim
        font.pixelSize: Theme.fsSm
    }

    Row {
        id: barRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.bottom: xAxis.top
        anchors.leftMargin: Theme.sp3
        anchors.rightMargin: Theme.sp3
        anchors.topMargin: Theme.sp2
        anchors.bottomMargin: 2
        spacing: 1
        visible: !chart.collapsed && chart.buckets.length > 0

        property int maxTotal: {
            let m = 1
            for (let i = 0; i < chart.buckets.length; i++) {
                let b = chart.buckets[i]
                let t = (b.ERROR || 0) + (b.WARN || 0)
                if (t > m) m = t
            }
            return m
        }

        Repeater {
            model: chart.buckets
            delegate: Item {
                id: bar
                width: chart.buckets.length > 0
                    ? Math.max(1, (barRow.width - (chart.buckets.length - 1)) / chart.buckets.length)
                    : 0
                height: barRow.height

                readonly property int cError: modelData.ERROR || 0
                readonly property int cWarn:  modelData.WARN  || 0
                readonly property int total: cError + cWarn
                readonly property real scale: barRow.maxTotal > 0 ? (height - 2) / barRow.maxTotal : 0

                readonly property bool isHovered: chart.hoverIndex === index

                // Stack bottom→top: WARN, ERROR.
                Rectangle {
                    id: segWarn
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: bar.cWarn * bar.scale
                    color: Theme.levelWarn
                    opacity: bar.isHovered && chart.hoverLevel === "WARN" ? 1.0 : (bar.isHovered ? 0.55 : 1.0)
                }
                Rectangle {
                    id: segError
                    width: parent.width
                    anchors.bottom: segWarn.top
                    height: bar.cError * bar.scale
                    color: Theme.levelError
                    opacity: bar.isHovered && chart.hoverLevel === "ERROR" ? 1.0 : (bar.isHovered ? 0.55 : 1.0)
                }

                Rectangle {
                    visible: bar.isHovered && bar.total > 0
                    z: 2
                    color: "transparent"
                    border.color: Theme.text
                    border.width: 2
                    radius: 2
                    width: parent.width
                    height: {
                        switch (chart.hoverLevel) {
                            case "ERROR": return bar.cError * bar.scale
                            case "WARN":  return bar.cWarn  * bar.scale
                            default:      return bar.total  * bar.scale
                        }
                    }
                    y: {
                        let bottom = parent.height
                        switch (chart.hoverLevel) {
                            case "ERROR": return bottom - (bar.cWarn + bar.cError) * bar.scale
                            case "WARN":  return bottom - bar.cWarn * bar.scale
                            default:      return bottom - bar.total * bar.scale
                        }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: bar.total > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

                    function _detectLevel(y) {
                        let segs = [
                            { level: "WARN",  h: bar.cWarn  * bar.scale },
                            { level: "ERROR", h: bar.cError * bar.scale }
                        ]
                        let bottom = bar.height
                        let acc = 0
                        for (let i = 0; i < segs.length; i++) {
                            let segBottom = bottom - acc
                            let segTop = segBottom - segs[i].h
                            if (segs[i].h > 0 && y >= segTop && y < segBottom) {
                                return segs[i].level
                            }
                            acc += segs[i].h
                        }
                        return ""
                    }

                    onEntered: {
                        chart.hoverIndex = index
                        chart.hoverCenterX = bar.mapToItem(chart, bar.width / 2, 0).x
                    }
                    onExited: {
                        if (chart.hoverIndex === index) {
                            chart.hoverIndex = -1
                            chart.hoverLevel = ""
                        }
                    }
                    onPositionChanged: (mouse) => {
                        chart.hoverLevel = _detectLevel(mouse.y)
                    }
                    onClicked: (mouse) => {
                        if (bar.total === 0) return
                        chart.bucketClicked(modelData.tMs, modelData.tMs + chart.bucketMs, _detectLevel(mouse.y))
                    }
                }
            }
        }
    }

    function _formatTick(ms) {
        let d = new Date(ms)
        if (chart.bucketMs < 60 * 1000)            return Qt.formatDateTime(d, "hh:mm:ss")
        if (chart.bucketMs < 60 * 60 * 1000)       return Qt.formatDateTime(d, "hh:mm")
        if (chart.bucketMs < 24 * 60 * 60 * 1000)  return Qt.formatDateTime(d, "MMM dd hh:mm")
        return Qt.formatDateTime(d, "MMM dd")
    }

    Item {
        id: xAxis
        anchors.left: barRow.left
        anchors.right: barRow.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 14
        visible: !chart.collapsed && chart.buckets.length > 0

        property int tickCount: chart.buckets.length <= 1 ? chart.buckets.length : 6
        property var tickIndices: {
            let n = chart.buckets.length
            if (n <= 1) return n === 1 ? [0] : []
            let count = Math.min(tickCount, n)
            let arr = []
            for (let i = 0; i < count; i++) {
                let idx = Math.round(i * (n - 1) / (count - 1))
                if (arr.indexOf(idx) === -1) arr.push(idx)
            }
            return arr
        }

        Repeater {
            model: xAxis.tickIndices
            delegate: Text {
                property int bucketIdx: modelData
                property real frac: chart.buckets.length > 1 ? bucketIdx / (chart.buckets.length - 1) : 0
                text: chart.buckets.length > bucketIdx
                    ? chart._formatTick(chart.buckets[bucketIdx].tMs)
                    : ""
                color: Theme.textDim
                font.pixelSize: Theme.fsXs
                x: {
                    if (frac <= 0) return 0
                    if (frac >= 1) return xAxis.width - width
                    return frac * xAxis.width - width / 2
                }
                y: 0
            }
        }
    }

    Rectangle {
        id: hoverCard
        visible: !chart.collapsed && chart.hoverIndex >= 0 && chart.hoverIndex < chart.buckets.length
        z: 100
        width: 200
        height: 52
        radius: Theme.rMd
        color: Theme.bgRaised
        border.width: 2
        border.color: hoverCard.levelColor

        readonly property var bucketData: (chart.hoverIndex >= 0 && chart.hoverIndex < chart.buckets.length)
                                    ? chart.buckets[chart.hoverIndex] : null
        readonly property color levelColor: {
            switch (chart.hoverLevel) {
                case "ERROR": return Theme.levelError
                case "WARN":  return Theme.levelWarn
                default:      return Theme.accent
            }
        }
        readonly property int currentCount: {
            let d = bucketData
            if (!d) return 0
            switch (chart.hoverLevel) {
                case "ERROR": return d.ERROR || 0
                case "WARN":  return d.WARN  || 0
                default:      return (d.ERROR || 0) + (d.WARN || 0)
            }
        }
        readonly property string levelLabel: chart.hoverLevel === "" ? "TOTAL" : chart.hoverLevel

        x: {
            let desired = chart.hoverCenterX - width / 2
            if (desired < 4) return 4
            if (desired + width > chart.width - 4) return chart.width - width - 4
            return desired
        }
        y: {
            let above = barRow.y - height - 6
            if (above >= 4) return above
            return barRow.y + barRow.height + 6
        }

        Column {
            x: Theme.sp2
            y: Theme.sp2
            width: hoverCard.width - Theme.sp2 * 2
            spacing: 2

            Text {
                width: parent.width
                text: hoverCard.bucketData
                    ? Qt.formatDateTime(new Date(hoverCard.bucketData.tMs), "MMM dd hh:mm:ss")
                      + " → " + Qt.formatDateTime(new Date(hoverCard.bucketData.tMs + chart.bucketMs), "hh:mm:ss")
                    : ""
                color: Theme.textMuted
                font.pixelSize: Theme.fsXs
                elide: Text.ElideRight
            }
            Row {
                spacing: 8
                Text {
                    text: hoverCard.levelLabel
                    color: hoverCard.levelColor
                    font.pixelSize: Theme.fsXs
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: hoverCard.currentCount
                    color: Theme.text
                    font.pixelSize: Theme.fsLg
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Rectangle {
        id: resizeHandle
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 6
        visible: !chart.collapsed
        color: resizeArea.pressed ? Theme.accent
             : resizeArea.containsMouse ? Theme.borderFocus
             : "transparent"
        opacity: resizeArea.containsMouse || resizeArea.pressed ? 0.5 : 1.0

        Row {
            anchors.centerIn: parent
            spacing: 3
            visible: !resizeArea.pressed
            Repeater {
                model: 3
                delegate: Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: resizeArea.containsMouse ? Theme.text : Theme.textDim
                }
            }
        }

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            anchors.topMargin: -2
            anchors.bottomMargin: -2
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            property int _startY: 0
            property int _startHeight: 0
            onPressed: (mouse) => {
                _startY = mouse.y
                _startHeight = chart.chartHeight
            }
            onPositionChanged: (mouse) => {
                if (!pressed) return
                let dy = mouse.y - _startY
                let h = _startHeight + dy
                if (h < chart.minChartHeight) h = chart.minChartHeight
                if (h > chart.maxChartHeight) h = chart.maxChartHeight
                chart.chartHeight = h
            }
        }
    }
}
