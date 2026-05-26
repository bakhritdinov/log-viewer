import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: root
    implicitHeight: layout.implicitHeight + Theme.sp4 * 2
    color: Theme.bgRaised
    border.color: Theme.border
    border.width: 1

    property alias searchText: searchField.text
    property alias timeRange: timeRange.timeRange
    property alias customFrom: timeRange.customFrom
    property alias customTo: timeRange.customTo
    // Visible label on the time-picker chip. Can be temporarily overridden
    // (e.g. by the histogram filter to show "12:00 → 12:01").
    property alias timeRangeDisplay: timeRange.display

    signal searchTriggered(string query)
    signal namespaceChanged(string ns)
    signal appChanged(string app)
    signal toggleSidebar()
    signal autoRefreshChanged(int seconds, bool tail)

    // Programmatic time range update (e.g. restoring pre-click state).
    // Unlike a direct timeRange property write, this also refreshes display
    // and emits changed().
    function applyTimeRange(tr, cf, ct) {
        timeRange.applyExternal(tr, cf, ct)
    }

    property bool sidebarOpen: false
    property int  autoRefreshSec: 0
    property bool autoTail: false

    property var mappings: ({})

    function focusSearch() { searchField.forceActiveFocus(); searchField.selectAll() }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.sp4
        spacing: Theme.sp3

        // Row 1: Sidebar toggle | Env switcher | NS | App | Time | Settings
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            SecondaryButton {
                text: root.sidebarOpen ? "✕  Fields" : "☰  Fields"
                Layout.preferredHeight: Theme.hButton + 4
                font.pixelSize: Theme.fsSm
                active: root.sidebarOpen
                ToolTip.visible: hovered
                ToolTip.text: root.sidebarOpen ? "Hide available fields" : "Show available fields"
                ToolTip.delay: 400
                onClicked: root.toggleSidebar()
            }

            // Env switcher — segmented control look
            Rectangle {
                Layout.preferredHeight: Theme.hButton + 4
                color: Theme.bgInput
                border.color: Theme.border
                border.width: 1
                radius: Theme.rMd
                implicitWidth: envRow.implicitWidth + 4

                RowLayout {
                    id: envRow
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 0
                    Repeater {
                        model: ["DEV", "PROD"]
                        Rectangle {
                            id: envChip
                            required property string modelData
                            property bool active: (typeof configManager !== "undefined" && configManager !== null) ? configManager.currentEnv === modelData : false
                            implicitWidth: 56
                            Layout.fillHeight: true
                            radius: Theme.rSm
                            color: active ? Theme.successDim
                                 : (envMouse.containsMouse ? Theme.bgSubtle : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.dFast } }
                            Text {
                                anchors.centerIn: parent
                                text: envChip.modelData
                                color: envChip.active ? Theme.textOnAccent : Theme.text
                                font.bold: true
                                font.pixelSize: Theme.fsXs
                                font.letterSpacing: 0.5
                            }
                            MouseArea {
                                id: envMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof configManager !== "undefined" && configManager !== null) {
                                        configManager.currentEnv = envChip.modelData
                                        root.mappings = {}
                                        nsCombo.model = []
                                        appCombo.model = []
                                        if (typeof grafanaClient !== "undefined" && grafanaClient !== null) {
                                            grafanaClient.fetchMappings(configManager.url(), configManager.token(), configManager.datasourceUid(), configManager.user(), configManager.password())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: 1; height: 22; color: Theme.border; Layout.leftMargin: Theme.sp1; Layout.rightMargin: Theme.sp1 }

            ScopedComboBox {
                id: nsCombo
                placeholder: "Namespace"
                onActivated: {
                    namespaceChanged(currentText)
                    let apps = (mappings[currentText] || []).sort()
                    appCombo.model = apps
                    if (apps.length > 0) {
                        appCombo.currentIndex = 0
                        appChanged(apps[0])
                    }
                }
            }

            ScopedComboBox {
                id: appCombo
                placeholder: "App"
                onActivated: appChanged(currentText)
            }

            Rectangle { width: 1; height: 22; color: Theme.border; Layout.leftMargin: Theme.sp1; Layout.rightMargin: Theme.sp1 }

            TimeRangePicker {
                id: timeRange
                onChanged: searchTriggered(searchField.text)
            }

            Item { Layout.fillWidth: true }

            // Theme toggle
            IconButton {
                text: Theme.dark ? "🌙" : "☀"
                tooltipText: Theme.dark ? "Switch to light mode" : "Switch to dark mode"
                pixel: Theme.fsXl
                boxSize: Theme.hButton + 4
                onClicked: Theme.dark = !Theme.dark
            }

            // Settings — prominent button, not just an icon.
            SecondaryButton {
                text: "⚙  Settings"
                Layout.preferredHeight: Theme.hButton + 4
                font.pixelSize: Theme.fsSm
                onClicked: settingsPopup.open()
            }
        }

        // Row 2: Search & Refresh
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            Rectangle {
                id: searchFieldBox
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.hInput + 2
                color: Theme.bgInput
                border.color: searchField.activeFocus ? Theme.borderFocus : Theme.border
                border.width: 1
                radius: Theme.rMd
                Behavior on border.color { ColorAnimation { duration: Theme.dFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp3
                    anchors.rightMargin: Theme.sp2
                    spacing: Theme.sp2

                    Text {
                        text: "🔍"
                        color: searchField.activeFocus ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.fsLg
                        Layout.alignment: Qt.AlignVCenter
                    }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search logs (LogsQL)…"
                        color: Theme.text
                        placeholderTextColor: Theme.textDim
                        font.pixelSize: Theme.fsLg
                        background: null
                        onAccepted: searchTriggered(text)
                    }
                    IconButton {
                        text: "▾"
                        visible: typeof configManager !== "undefined" && configManager !== null
                              && configManager.searchHistory().length > 0
                        tooltipText: "Recent searches"
                        pixel: Theme.fsLg
                        boxSize: 26
                        iconColor: Theme.textMuted
                        iconHoverColor: Theme.accent
                        active: historyPopup.opened
                        onClicked: historyPopup.opened ? historyPopup.close() : historyPopup.open()
                    }
                    IconButton {
                        text: "✕"
                        visible: searchField.text !== ""
                        tooltipText: "Clear"
                        pixel: Theme.fsLg
                        boxSize: 26
                        iconColor: Theme.textMuted
                        iconHoverColor: Theme.danger
                        onClicked: searchField.clear()
                    }
                }

                Popup {
                    id: historyPopup
                    parent: searchFieldBox
                    x: 0
                    y: searchFieldBox.height + 4
                    width: searchFieldBox.width
                    padding: 1
                    background: Rectangle { color: Theme.bgRaised; border.color: Theme.border; border.width: 1; radius: Theme.rMd }
                    contentItem: ColumnLayout {
                        spacing: 0
                        Repeater {
                            model: (typeof configManager !== "undefined" && configManager !== null)
                                ? configManager.searchHistory() : []
                            delegate: ItemDelegate {
                                Layout.fillWidth: true
                                implicitHeight: 30
                                contentItem: Text {
                                    text: modelData
                                    color: Theme.text
                                    font.pixelSize: Theme.fsSm
                                    elide: Text.ElideRight
                                    leftPadding: Theme.sp3
                                    rightPadding: Theme.sp3
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle { color: parent.hovered ? Theme.bgSubtle : "transparent"; radius: Theme.rSm }
                                onClicked: {
                                    searchField.text = modelData
                                    historyPopup.close()
                                    searchTriggered(modelData)
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.borderMuted
                        }
                        ItemDelegate {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            contentItem: Text {
                                text: "Clear history"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fsXs
                                font.italic: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: parent.hovered ? Theme.bgSubtle : "transparent"; radius: Theme.rSm }
                            onClicked: {
                                if (typeof configManager !== "undefined" && configManager !== null)
                                    configManager.clearSearchHistory()
                                historyPopup.close()
                            }
                        }
                    }
                }
            }

            // Split button: refresh-now on the left, auto-refresh interval picker on the right.
            Rectangle {
                id: refreshSplit
                Layout.preferredHeight: Theme.hInput + 2
                implicitWidth: refreshNowBtn.width + 1 + dropdownBtn.width
                color: "transparent"

                Button {
                    id: refreshNowBtn
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Theme.hInput + 2
                    onClicked: { refreshAnim.start(); searchTriggered(searchField.text) }
                    background: Rectangle {
                        radius: Theme.rMd
                        // round only the left side
                        color: refreshNowBtn.down ? Theme.success : Theme.successDim
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                        Rectangle { // right edge — straighten the corner so it visually fuses with the dropdown
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.radius
                            color: parent.color
                        }
                    }
                    contentItem: Text {
                        id: refreshIcon
                        text: "↻"
                        color: Theme.textOnAccent
                        font.pixelSize: 20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    RotationAnimation { id: refreshAnim; target: refreshIcon; from: 0; to: 360; duration: 500; running: false }
                }

                Rectangle { // 1px divider between the two halves
                    anchors.left: refreshNowBtn.right
                    anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: 1
                    color: Qt.rgba(0, 0, 0, 0.25)
                }

                Button {
                    id: dropdownBtn
                    anchors.left: refreshNowBtn.right
                    anchors.leftMargin: 1
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: dropdownContent.implicitWidth + Theme.sp3 * 2
                    ToolTip.visible: hovered
                    ToolTip.text: root.autoRefreshSec === 0
                        ? "Auto-refresh: Off"
                        : (root.autoTail ? "Tail mode (5s)" : `Auto-refresh every ${root.autoRefreshSec}s`)
                    ToolTip.delay: 400
                    onClicked: autoRefreshPopup.opened ? autoRefreshPopup.close() : autoRefreshPopup.open()
                    background: Rectangle {
                        radius: Theme.rMd
                        color: dropdownBtn.down ? Theme.success : Theme.successDim
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                        Rectangle { // left edge — straighten the corner
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.radius
                            color: parent.color
                        }
                    }
                    contentItem: Row {
                        id: dropdownContent
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            visible: text !== ""
                            text: root.autoRefreshSec === 0 ? "" : (root.autoTail ? "Tail" : root.autoRefreshSec + "s")
                            color: Theme.textOnAccent
                            font.pixelSize: Theme.fsSm
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "▾"
                            color: Theme.textOnAccent
                            font.pixelSize: Theme.fsSm
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Popup {
                        id: autoRefreshPopup
                        x: dropdownBtn.width - width
                        y: dropdownBtn.height + 4
                        width: 170
                        padding: Theme.sp1
                        background: Rectangle { color: Theme.bgRaised; border.color: Theme.border; border.width: 1; radius: Theme.rMd }
                        contentItem: Column {
                            spacing: 1

                            Text {
                                width: parent.width
                                leftPadding: Theme.sp3
                                topPadding: Theme.sp2
                                bottomPadding: Theme.sp1
                                text: "AUTO-REFRESH"
                                color: Theme.textMuted
                                font.bold: true
                                font.pixelSize: Theme.fsXs
                                font.letterSpacing: 0.5
                            }

                            Repeater {
                                model: [
                                    {label: "Off",       secs: 0,  tail: false},
                                    {label: "5s",        secs: 5,  tail: false},
                                    {label: "10s",       secs: 10, tail: false},
                                    {label: "30s",       secs: 30, tail: false},
                                    {label: "1m",        secs: 60, tail: false},
                                    {label: "Tail (5s)", secs: 5,  tail: true}
                                ]
                                delegate: Rectangle {
                                    id: optRow
                                    width: parent.width
                                    height: 28
                                    radius: Theme.rSm

                                    property bool active: (modelData.secs === root.autoRefreshSec)
                                                       && (modelData.tail === root.autoTail)
                                    color: optMouse.containsMouse ? Theme.bgSubtle : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.dFast } }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.sp3
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        color: optRow.active ? Theme.accent : Theme.text
                                        font.pixelSize: Theme.fsSm
                                        font.bold: optRow.active
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.sp3
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "✓"
                                        color: Theme.accent
                                        font.pixelSize: Theme.fsSm
                                        font.bold: true
                                        visible: optRow.active
                                    }
                                    MouseArea {
                                        id: optMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.autoRefreshSec = modelData.secs
                                            root.autoTail = modelData.tail
                                            root.autoRefreshChanged(modelData.secs, modelData.tail)
                                            autoRefreshPopup.close()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Pulsing dot when auto-refresh active
                Rectangle {
                    anchors.top: parent.top; anchors.right: parent.right
                    anchors.topMargin: 4; anchors.rightMargin: 4
                    width: 8; height: 8; radius: 4
                    color: root.autoTail ? Theme.warn : Theme.accent
                    visible: root.autoRefreshSec > 0
                    SequentialAnimation on opacity {
                        running: root.autoRefreshSec > 0
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    }
                }
            }
        }
    }

    component ScopedComboBox : ComboBox {
        id: cbRoot
        property string placeholder: ""
        font.pixelSize: Theme.fsMd
        implicitHeight: Theme.hButton + 4

        // Adaptive width — sized to the widest item in the model so the
        // dropdown doesn't jump in width when the selection changes.
        TextMetrics {
            id: _cbMetrics
            font: cbRoot.font
        }
        property real _widestItem: 0
        function _recomputeWidest() {
            let mdl = cbRoot.model
            let n = 0
            if (mdl) n = (typeof mdl.length === "number") ? mdl.length
                       : (typeof mdl.count  === "number") ? mdl.count : 0
            let m = 0
            for (let i = 0; i < n; i++) {
                let item = (typeof mdl.get === "function") ? mdl.get(i) : mdl[i]
                _cbMetrics.text = String(item)
                if (_cbMetrics.width > m) m = _cbMetrics.width
            }
            if (m === 0 && placeholder) {
                _cbMetrics.text = placeholder
                m = _cbMetrics.width
            }
            _widestItem = m
        }
        onModelChanged: _recomputeWidest()
        Component.onCompleted: _recomputeWidest()
        // Width = widest item + padding for the dropdown indicator and a small
        // buffer for the TextMetrics ↔ Text.contentWidth gap.
        Layout.preferredWidth: _widestItem + 90
        Layout.minimumWidth: 80
        Layout.fillWidth: false

        background: Rectangle {
            color: Theme.bgInput
            border.color: cbRoot.activeFocus ? Theme.borderFocus : Theme.border
            border.width: 1
            radius: Theme.rMd
            Behavior on border.color { ColorAnimation { duration: Theme.dFast } }
        }
        contentItem: Text {
            text: cbRoot.displayText !== "" ? cbRoot.displayText : cbRoot.placeholder
            color: cbRoot.displayText !== "" ? Theme.text : Theme.textDim
            font: cbRoot.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            leftPadding: Theme.sp3
            rightPadding: 24
        }

        // Qt 6.2 (Ubuntu 22.04) does NOT auto-wrap an Item into Component
        // when bound to ComboBox.delegate — without an explicit Component {}
        // it raises "Cannot assign ItemDelegate to QQmlComponent*".
        delegate: Component {
            ItemDelegate {
                width: Math.max(cbRoot.width, 120)
                contentItem: Text {
                    text: modelData
                    color: hovered ? Theme.textOnAccent : Theme.text
                    font: cbRoot.font
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: Theme.sp3
                }
                background: Rectangle { color: hovered ? Theme.bgSubtle : "transparent" }
            }
        }

        popup: Popup {
            y: cbRoot.height + 2
            width: Math.max(cbRoot.width, 140)
            implicitHeight: Math.min(contentItem.implicitHeight + 2, 400)
            padding: 1
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: cbRoot.delegateModel
                ScrollBar.vertical: ScrollBar { }
            }
            background: Rectangle { color: Theme.bgRaised; border.color: Theme.border; border.width: 1; radius: Theme.rMd }
        }
    }

    Connections {
        target: grafanaClient
        function onMappingsReceived(m) {
            mappings = m
            let nss = Object.keys(m).sort()
            nsCombo.model = nss
            if (nss.length === 0) return

            // Restore last-used namespace if it still exists, otherwise pick the first.
            let lastNs = (typeof configManager !== "undefined" && configManager !== null)
                ? configManager.lastNamespace() : ""
            let nsIdx = (lastNs && nss.indexOf(lastNs) !== -1) ? nss.indexOf(lastNs) : 0
            nsCombo.currentIndex = nsIdx
            let pickedNs = nss[nsIdx]
            namespaceChanged(pickedNs)

            let apps = (m[pickedNs] || []).sort()
            appCombo.model = apps
            if (apps.length === 0) return

            let lastApp = (typeof configManager !== "undefined" && configManager !== null)
                ? configManager.lastApp() : ""
            let appIdx = (lastApp && apps.indexOf(lastApp) !== -1) ? apps.indexOf(lastApp) : 0
            appCombo.currentIndex = appIdx
            appChanged(apps[appIdx])
        }
    }

    Component.onCompleted: {
        // Restore last-used time range as the picker's initial state.
        if (typeof configManager !== "undefined" && configManager !== null) {
            let saved = configManager.lastTimeRange()
            let savedFrom = configManager.lastCustomFrom()
            let savedTo = configManager.lastCustomTo()
            // applyExternal sanitizes "Custom" with empty dates → 1h fallback,
            // otherwise the chip would show "? → ?".
            timeRange.applyExternal(saved || "1h", savedFrom, savedTo)
        }
    }

    SettingsDialog { id: settingsPopup }
}
