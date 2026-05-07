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

    signal searchTriggered(string query)
    signal namespaceChanged(string ns)
    signal appChanged(string app)
    signal toggleSidebar()

    property bool sidebarOpen: false

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
                                            grafanaClient.fetchMappings(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password())
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
                Layout.preferredWidth: 170
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
                Layout.preferredWidth: 170
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
            }

            Button {
                id: refreshButton
                Layout.preferredHeight: Theme.hInput + 2
                Layout.preferredWidth: Theme.hInput + 2
                onClicked: { refreshAnim.start(); searchTriggered(searchField.text) }
                background: Rectangle {
                    color: refreshButton.down ? Theme.success : Theme.successDim
                    radius: Theme.rMd
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }
                }
                contentItem: Text {
                    text: "↻"
                    color: Theme.textOnAccent
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                RotationAnimation { id: refreshAnim; target: refreshButton.contentItem; from: 0; to: 360; duration: 500; running: false }
            }
        }
    }

    component ScopedComboBox : ComboBox {
        id: cbRoot
        property string placeholder: ""
        font.pixelSize: Theme.fsMd
        implicitHeight: Theme.hButton + 4

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

        delegate: ItemDelegate {
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
            if (nss.length > 0) {
                nsCombo.currentIndex = 0
                namespaceChanged(nss[0])
                let apps = (m[nss[0]] || []).sort()
                appCombo.model = apps
                if (apps.length > 0) {
                    appCombo.currentIndex = 0
                    appChanged(apps[0])
                }
            }
        }
    }

    SettingsDialog { id: settingsPopup }
}
