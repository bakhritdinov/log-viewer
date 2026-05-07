import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    implicitHeight: layout.implicitHeight + 30
    color: "#161b22"
    border.color: "#30363d"
    
    property alias searchText: searchField.text
    property string timeRange: timeCombo.currentText
    property string customFrom: fromField.text
    property string customTo: toField.text

    signal searchTriggered(string query)
    signal namespaceChanged(string ns)
    signal appChanged(string app)

    property var mappings: ({})

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // Row 1: Env, NS, App, Time, Settings
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                spacing: 4
                Repeater {
                    model: ["DEV", "PROD"]
                    Button {
                        text: modelData
                        property bool active: (typeof configManager !== "undefined" && configManager !== null) ? configManager.currentEnv === modelData : false
                        onClicked: {
                            if (typeof configManager !== "undefined" && configManager !== null) {
                                configManager.currentEnv = modelData
                                mappings = {} 
                                nsCombo.model = []
                                appCombo.model = []
                                if (typeof grafanaClient !== "undefined" && grafanaClient !== null) {
                                    grafanaClient.fetchMappings(configManager.url(), "", configManager.datasourceUid(), configManager.user(), configManager.password())
                                }
                            }
                        }
                        font.bold: true; font.pixelSize: 11
                        background: Rectangle {
                            color: parent.active ? "#238636" : (parent.down ? "#30363d" : "#21262d")
                            border.color: parent.active ? "#2ea043" : "#30363d"
                            radius: 6; implicitWidth: 60; implicitHeight: 32
                        }
                        contentItem: Text { text: parent.text; color: parent.active ? "#ffffff" : "#c9d1d9"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            Rectangle { width: 1; height: 20; color: "#30363d"; Layout.leftMargin: 5; Layout.rightMargin: 5 }

            CustomComboBox {
                id: nsCombo
                Layout.preferredWidth: 160
                contentItem: Text { 
                    text: nsCombo.displayText; color: "#c9d1d9"
                    verticalAlignment: Text.AlignVCenter; leftPadding: 12 
                }
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

            CustomComboBox {
                id: appCombo
                Layout.preferredWidth: 160
                contentItem: Text { 
                    text: appCombo.displayText; color: "#c9d1d9"
                    verticalAlignment: Text.AlignVCenter; leftPadding: 12 
                }
                onActivated: appChanged(currentText)
            }

            CustomComboBox {
                id: timeCombo
                Layout.preferredWidth: 100
                model: ["5m", "15m", "1h", "3h", "6h", "12h", "24h", "Custom"]
                currentIndex: 2
                contentItem: Text { 
                    text: timeCombo.displayText; color: "#c9d1d9"
                    verticalAlignment: Text.AlignVCenter; leftPadding: 12 
                }
                onActivated: {
                    if (currentText !== "Custom") searchTriggered(searchField.text)
                }
            }

            // Custom Range inline
            RowLayout {
                visible: timeCombo.currentText === "Custom"
                spacing: 5
                
                // From field
                Rectangle {
                    Layout.preferredWidth: 155; height: 32
                    color: "#0d1117"; border.color: "#30363d"; radius: 6
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 2; spacing: 0
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            TextField { anchors.fill: parent; id: fromField; placeholderText: "From"; color: "#c9d1d9"; font.pixelSize: 12; readOnly: true; background: null; verticalAlignment: TextInput.AlignVCenter }
                            MouseArea { anchors.fill: parent; onClicked: calendarPopup.setTarget(fromField, false) }
                        }
                        Button {
                            text: "✕"; visible: fromField.text !== ""; Layout.preferredWidth: 24; Layout.preferredHeight: 24; Layout.alignment: Qt.AlignVCenter
                            onClicked: { fromField.text = ""; window.refreshLogs(window.searchHeader.searchText) }
                            background: null; contentItem: Text { text: parent.text; color: "#f85149"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }

                Text { text: "→"; color: "#8b949e"; Layout.alignment: Qt.AlignVCenter }

                // To field
                Rectangle {
                    Layout.preferredWidth: 155; height: 32
                    color: "#0d1117"; border.color: "#30363d"; radius: 6
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 2; spacing: 0
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            TextField { anchors.fill: parent; id: toField; placeholderText: "To"; color: "#c9d1d9"; font.pixelSize: 12; readOnly: true; background: null; verticalAlignment: TextInput.AlignVCenter }
                            MouseArea { anchors.fill: parent; onClicked: calendarPopup.setTarget(toField, true) }
                        }
                        Button {
                            text: "✕"; visible: toField.text !== ""; Layout.preferredWidth: 24; Layout.preferredHeight: 24; Layout.alignment: Qt.AlignVCenter
                            onClicked: { toField.text = ""; window.refreshLogs(window.searchHeader.searchText) }
                            background: null; contentItem: Text { text: parent.text; color: "#f85149"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "⚙"
                onClicked: settingsPopup.open()
                background: Rectangle { color: parent.down ? "#30363d" : "#21262d"; border.color: "#30363d"; radius: 6; implicitWidth: 36; implicitHeight: 36 }
                contentItem: Text { text: parent.text; color: "#c9d1d9"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }

        // Row 2: Search & Refresh
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                height: 38
                color: "#0d1117"; border.color: searchField.activeFocus ? "#58a6ff" : "#30363d"; radius: 6
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8
                    TextField {
                        id: searchField; Layout.fillWidth: true; placeholderText: "Search logs (LogQL)..."
                        color: "#c9d1d9"; font.pixelSize: 14; background: null
                        onAccepted: searchTriggered(text)
                    }
                    Button {
                        text: "✕"; visible: searchField.text !== ""; onClicked: searchField.clear()
                        background: null; contentItem: Text { text: parent.text; color: "#8b949e"; font.pixelSize: 16 }
                    }
                }
            }

            Button {
                id: refreshButton
                onClicked: { refreshAnim.start(); searchTriggered(searchField.text) }
                Layout.preferredHeight: 38; Layout.preferredWidth: 38
                background: Rectangle { color: parent.down ? "#2ea043" : "#238636"; radius: 6 }
                contentItem: Text { text: "↻"; color: "#ffffff"; font.pixelSize: 20; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                RotationAnimation { id: refreshAnim; target: refreshButton.contentItem; from: 0; to: 360; duration: 500; running: false }
            }
        }
    }

    CalendarPopup {
        id: calendarPopup
    }

    component CustomComboBox : ComboBox {
        id: cbRoot
        font.pixelSize: 13
        background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6; implicitHeight: 36 }
        
        delegate: ItemDelegate {
            width: Math.max(cbRoot.width, 120)
            contentItem: Text {
                text: modelData; color: hovered ? "#ffffff" : "#c9d1d9"
                font: cbRoot.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: hovered ? "#21262d" : "#0d1117" }
        }
        
        popup: Popup {
            y: cbRoot.height + 1; width: Math.max(cbRoot.width, 120)
            implicitHeight: Math.min(contentItem.implicitHeight + 2, 400); padding: 1
            contentItem: ListView {
                clip: true; implicitHeight: contentHeight; model: cbRoot.delegateModel; ScrollBar.vertical: ScrollBar { }
            }
            background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6 }
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
