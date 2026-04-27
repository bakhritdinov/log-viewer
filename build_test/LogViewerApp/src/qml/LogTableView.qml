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
    signal loadMoreRequested()

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
            
            onAtYEndChanged: {
                if (atYEnd && count > 0 && !logModel.loading) {
                    tableRoot.loadMoreRequested()
                }
            }

            footer: Rectangle {
                width: logList.width; height: 40
                color: "transparent"
                visible: logModel.loading && logList.count > 0
                BusyIndicator {
                    anchors.centerIn: parent; width: 24; height: 24
                }
            }

            delegate: Rectangle {
                width: logList.width; height: 28
                color: logList.currentIndex === index ? "#21262d" : (
                    level === "ERROR" ? "rgba(248, 81, 73, 0.1)" : (
                    level === "WARN" ? "rgba(210, 153, 34, 0.1)" : "transparent"
                ))

                Row {
                    id: rowItem
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 5
                    
                    LogText { text: timestamp; width: timeWidth; color: "#8b949e" }
                    LogText { 
                        text: level; width: levelWidth
                        color: level === "ERROR" ? "#f85149" : (level === "WARN" ? "#d29922" : "#c9d1d9")
                        font.bold: true; horizontalAlignment: Text.AlignHCenter
                    }
                    LogText { text: service; width: serviceWidth; color: "#c9d1d9" }
                    
                    // Сообщение с жестким ограничением
                    LogText { 
                        text: message.replace(/\n/g, " "); // Убираем переносы строк для компактности
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
                        let entry = {
                            timestamp: timestamp, level: level, service: service,
                            pod: pod, traceId: traceId, message: message, allFields: allFields
                        }
                        rowSelected(entry)
                        if (mouse.button === Qt.RightButton && traceId) {
                            contextMenu.currentTraceId = traceId
                            contextMenu.popup()
                        }
                    }
                }
            }
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
