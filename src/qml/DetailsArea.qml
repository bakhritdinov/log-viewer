import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: detailsRoot
    color: "#0d1117"
    border.color: "#30363d"
    border.width: 1

    property var currentEntry: null

    function setEntry(entry) {
        currentEntry = entry
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Header with Copy button
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "LOG DETAILS"
                font.bold: true; font.pixelSize: 12; color: "#8b949e"
                Layout.fillWidth: true
            }
            Button {
                text: "📋 Copy Message"
                visible: currentEntry !== null
                onClicked: {
                    let text = `MESSAGE: ${currentEntry.message}\n\nFIELDS:\n`
                    let f = currentEntry.fields
                    Object.keys(f).sort().forEach(k => {
                        text += `${k}: ${f[k]}\n`
                    })
                    tempTextArea.text = text
                    tempTextArea.selectAll()
                    tempTextArea.copy()
                }
                background: Rectangle { color: parent.down ? "#30363d" : "#21262d"; border.color: "#30363d"; radius: 4 }
                contentItem: Text { text: parent.text; color: "#c9d1d9"; font.pixelSize: 11; padding: 4 }
            }
        }

        ScrollView {
            id: scrollView 
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth 

            ColumnLayout {
                width: scrollView.availableWidth 
                spacing: 10

                // Main Message
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: msgText.implicitHeight + 20
                    color: "#161b22"; radius: 6; border.color: "#30363d"
                    TextEdit {
                        id: msgText
                        anchors.fill: parent; anchors.margins: 10
                        text: currentEntry ? currentEntry.message : "Select a log entry..."
                        color: "#c9d1d9"; font.family: "Monospace"; font.pixelSize: 13
                        readOnly: true; wrapMode: TextEdit.Wrap
                        selectByMouse: true
                    }
                }

                Label {
                    text: "ALL FIELDS"
                    font.bold: true; font.pixelSize: 11; color: "#8b949e"
                    topPadding: 10
                }

                // Fields Grid
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: currentEntry ? Object.keys(currentEntry.fields).sort() : []
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: fieldRow.implicitHeight + 8
                            color: index % 2 === 0 ? "transparent" : "rgba(110, 118, 129, 0.05)"
                            radius: 4
                            
                            RowLayout {
                                id: fieldRow
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 10
                                
                                Text {
                                    text: modelData
                                    color: "#8b949e"; font.pixelSize: 12; font.bold: true
                                    Layout.preferredWidth: 150
                                    Layout.alignment: Qt.AlignTop
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    id: fieldValueText
                                    text: (typeof logModel !== "undefined" && logModel !== null && currentEntry !== null)
                                        ? logModel.formatValue(currentEntry.fields[modelData])
                                        : ""
                                    color: "#c9d1d9"; font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    font.family: "Monospace"
                                }

                                RowLayout {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignTop
                                    
                                    // Кнопка поиска по значению
                                    Button {
                                        width: 24; height: 24
                                        flat: true
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Add to search"
                                        contentItem: Text { 
                                            text: "🔍"
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            color: parent.hovered ? "#58a6ff" : "#8b949e"
                                        }
                                        background: Rectangle { 
                                            color: parent.hovered ? "#21262d" : "transparent"
                                            radius: 4 
                                        }
                                        onClicked: window.toggleFilter(modelData, currentEntry.fields[modelData])
                                    }

                                    // Кнопка копирования значения
                                    Button {
                                        width: 24; height: 24
                                        flat: true
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Copy value"
                                        contentItem: Text { 
                                            text: "📋"
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            color: parent.hovered ? "#58a6ff" : "#8b949e"
                                        }
                                        background: Rectangle { 
                                            color: parent.hovered ? "#21262d" : "transparent"
                                            radius: 4 
                                        }
                                        onClicked: {
                                            tempTextArea.text = fieldValueText.text
                                            tempTextArea.selectAll()
                                            tempTextArea.copy()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    TextArea { id: tempTextArea; visible: false }
}
