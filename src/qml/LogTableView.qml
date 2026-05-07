import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: tableRoot
    color: "#0d1117"
    border.color: "#30363d"
    border.width: 1

    signal rowSelected(var entry)
    signal traceRequested(string traceId)
    signal firstPageRequested()
    signal prevPageRequested()
    signal nextPageRequested()
    signal lastPageRequested()

    property int currentPage: 0
    property int maxPage: 1

    readonly property int timeWidth: 180
    readonly property int levelWidth: 80
    readonly property int serviceWidth: 150

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true; height: 32; color: "#161b22"
            z: 2
            Row {
                anchors.fill: parent
                HeaderLabel { text: "Time"; width: timeWidth }
                HeaderLabel { text: "Level"; width: levelWidth }
                HeaderLabel { text: "Service"; width: serviceWidth }
                HeaderLabel { text: "Message"; width: parent.width - timeWidth - levelWidth - serviceWidth }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#30363d" }
        }

        ListView {
            id: logList
            Layout.fillWidth: true; Layout.fillHeight: true
            model: logModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                width: logList.width; height: 28
                // Безопасное извлечение уровня
                property string itemLevel: (typeof fields !== "undefined" && fields !== null) ? (fields.level || "") : ""
                
                color: logList.currentIndex === index ? "#21262d" : (
                    itemLevel === "ERROR" ? "rgba(248, 81, 73, 0.1)" : (
                    itemLevel === "WARN" ? "rgba(210, 153, 34, 0.1)" : "transparent"
                ))

                Row {
                    id: rowItem
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 5
                    
                    LogText { text: timestamp; width: timeWidth; color: "#8b949e" }
                    LogText { 
                        text: itemLevel; width: levelWidth
                        color: itemLevel === "ERROR" ? "#f85149" : (itemLevel === "WARN" ? "#d29922" : "#c9d1d9")
                        font.bold: true; horizontalAlignment: Text.AlignHCenter
                    }
                    LogText { 
                        text: (typeof fields !== "undefined" && fields !== null) ? (fields.service || "") : ""; 
                        width: serviceWidth; color: "#c9d1d9" 
                    }
                    
                    LogText { 
                        text: message.replace(/\n/g, " "); 
                        width: rowItem.width - timeWidth - levelWidth - serviceWidth - 10
                        color: "#c9d1d9"
                        clip: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#21262d"; opacity: 0.3 }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        logList.currentIndex = index
                        let currentFields = (typeof fields !== "undefined" && fields !== null) ? fields : {}
                        rowSelected({
                            timestamp: timestamp, 
                            message: message, 
                            fields: currentFields
                        })
                        
                        if (mouse.button === Qt.RightButton && currentFields.traceId) {
                            contextMenu.currentTraceId = currentFields.traceId
                            contextMenu.popup()
                        }
                    }
                }
            }
        }

        Rectangle {
            id: pageBar
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#161b22"

            readonly property bool busy: typeof logModel !== "undefined" && logModel !== null && logModel.loading

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#30363d" }

            BusyIndicator {
                anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                running: pageBar.busy
                visible: running
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                PageButton {
                    text: "« First"
                    enabled: tableRoot.currentPage > 0 && !pageBar.busy
                    onClicked: tableRoot.firstPageRequested()
                }

                PageButton {
                    text: "← Newer"
                    enabled: tableRoot.currentPage > 0 && !pageBar.busy
                    onClicked: tableRoot.prevPageRequested()
                }

                Text {
                    text: `Page ${tableRoot.currentPage + 1} of ${tableRoot.maxPage}`
                    color: "#8b949e"; font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                }

                PageButton {
                    text: "Older →"
                    enabled: tableRoot.currentPage + 1 < tableRoot.maxPage && !pageBar.busy
                    onClicked: tableRoot.nextPageRequested()
                }

                PageButton {
                    text: "Last »"
                    enabled: tableRoot.currentPage + 1 < tableRoot.maxPage && !pageBar.busy
                    onClicked: tableRoot.lastPageRequested()
                }
            }

            Text {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: `${(typeof logModel !== "undefined" && logModel !== null) ? logModel.count : 0} logs`
                color: "#8b949e"; font.pixelSize: 12
            }
        }
    }

    component PageButton : Button {
        Layout.preferredHeight: 26
        font.pixelSize: 11
        background: Rectangle {
            color: parent.enabled ? (parent.down ? "#30363d" : "#21262d") : "#161b22"
            border.color: parent.enabled ? "#30363d" : "#21262d"
            radius: 4
        }
        contentItem: Text {
            text: parent.text
            color: parent.enabled ? "#c9d1d9" : "#484f58"
            font: parent.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            leftPadding: 10; rightPadding: 10
        }
    }

    Menu {
        id: contextMenu
        property string currentTraceId: ""
        background: Rectangle { color: "#161b22"; border.color: "#30363d"; radius: 6 }
        MenuItem {
            text: "🔍 Fetch Trace Context (±5m)"
            onTriggered: traceRequested(contextMenu.currentTraceId)
            contentItem: Text { text: parent.text; color: "#c9d1d9"; padding: 5 }
            background: Rectangle { color: parent.highlighted ? "#21262d" : "transparent"; radius: 4 }
        }
    }

    component HeaderLabel : Rectangle {
        property alias text: lbl.text
        height: parent.height; color: "transparent"
        Text { id: lbl; anchors.centerIn: parent; color: "#8b949e"; font.bold: true; font.pixelSize: 11; font.capitalization: Font.AllUppercase }
        Rectangle { anchors.right: parent.right; height: parent.height * 0.6; anchors.verticalCenter: parent.verticalCenter; width: 1; color: "#30363d" }
    }

    component LogText : Text {
        font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; padding: 4
        maximumLineCount: 1
        wrapMode: Text.NoWrap
    }
}
