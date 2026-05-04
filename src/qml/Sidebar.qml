import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebarRoot
    color: "#0d1117"
    border.color: "#30363d"
    border.width: 1

    property var facets: ({})
    property string filterText: fieldSearch.text.toLowerCase()
    property string expandedField: ""

    signal expansionChanged(bool expanded)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12
        
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "AVAILABLE FIELDS"
                font.bold: true; font.pixelSize: 11; color: "#8b949e"; Layout.fillWidth: true
            }
            Button {
                text: "✕ Clear"; visible: fieldSearch.text !== ""
                onClicked: fieldSearch.clear()
                font.pixelSize: 11
                contentItem: Text { text: parent.text; color: "#f85149"; font.pixelSize: 11; font.bold: true }
                background: null
            }
        }

        TextField {
            id: fieldSearch
            Layout.fillWidth: true; placeholderText: "Search fields..."
            font.pixelSize: 13; color: "#c9d1d9"; padding: 10
            background: Rectangle { color: "#010409"; border.color: fieldSearch.activeFocus ? "#58a6ff" : "#30363d"; radius: 6 }
        }

        ListView {
            id: fieldsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            
            model: {
                if (!facets) return [];
                let keys = Object.keys(facets);
                if (filterText !== "") {
                    keys = keys.filter(k => {
                        if (k.toLowerCase().includes(filterText)) return true;
                        let values = Object.keys(facets[k]);
                        return values.some(v => v.toLowerCase().includes(filterText));
                    });
                }
                return keys.sort();
            }

            delegate: Column {
                id: fieldGroup
                width: fieldsList.width
                property string fieldName: modelData
                property var fieldValues: facets ? facets[fieldName] : ({})
                // Автоматически разворачиваем поле, если поиск совпал со значением
                property bool isExpanded: sidebarRoot.expandedField === fieldName || (filterText !== "" && !fieldName.toLowerCase().includes(filterText))

                // Заголовок поля (фиксированная высота)
                Rectangle {
                    width: parent.width
                    height: 32
                    color: groupMouse.containsMouse ? "#21262d" : "transparent"
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            text: isExpanded ? "▼ " + fieldName : "▶ " + fieldName
                            color: isExpanded ? "#58a6ff" : "#c9d1d9"
                            font.pixelSize: 13; font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: fieldValues ? Object.keys(fieldValues).length : 0
                            color: "#8b949e"; font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: groupMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (sidebarRoot.expandedField === fieldName) {
                                sidebarRoot.expandedField = "";
                                sidebarRoot.expansionChanged(false);
                            } else {
                                sidebarRoot.expandedField = fieldName;
                                sidebarRoot.expansionChanged(true);
                            }
                        }
                    }
                }

                // Список подполей (динамический)
                Column {
                    width: parent.width
                    visible: isExpanded
                    leftPadding: 15
                    topPadding: 2
                    bottomPadding: 5
                    spacing: 1

                    Repeater {
                        model: {
                            if (!isExpanded || !fieldValues) return [];
                            let vKeys = Object.keys(fieldValues);
                            if (filterText !== "" && !fieldName.toLowerCase().includes(filterText)) {
                                vKeys = vKeys.filter(v => v.toLowerCase().includes(filterText));
                            }
                            return vKeys.sort((a, b) => fieldValues[b] - fieldValues[a]).slice(0, 50);
                        }
                        delegate: ItemDelegate {
                            width: fieldGroup.width - 20
                            height: 28
                            padding: 5
                            
                            property bool isActive: window.searchHeader.searchText.indexOf(fieldName + ":\"" + modelData + "\"") !== -1
                            
                            contentItem: RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData
                                    color: isActive ? "#58a6ff" : "#8b949e"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: fieldValues[modelData] || ""
                                    color: "#484f58"; font.pixelSize: 11
                                }
                                Text {
                                    text: "✕"
                                    color: "#f85149"
                                    font.pixelSize: 10
                                    visible: isActive
                                }
                            }
                            onClicked: {
                                let current = window.searchHeader.searchText;
                                let filter = fieldName + ":\"" + modelData + "\"";
                                
                                if (current.indexOf(filter) !== -1) {
                                    // Удаляем фильтр
                                    let parts = current.split(" AND ").filter(p => p.trim() !== filter);
                                    window.searchHeader.searchText = parts.join(" AND ");
                                } else {
                                    // Добавляем фильтр
                                    if (current && current.trim() !== "" && current !== "*") {
                                        window.searchHeader.searchText = current + " AND " + filter;
                                    } else {
                                        window.searchHeader.searchText = filter;
                                    }
                                }
                                window.refreshLogs(window.searchHeader.searchText);
                            }
                            background: Rectangle { color: hovered ? "#161b22" : "transparent"; radius: 4 }
                        }
                    }
                }
            }
        }

        // Footer with Version and Update Info
        Rectangle {
            id: sidebarFooter
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.leftMargin: -10; Layout.rightMargin: -10; Layout.bottomMargin: -10
            color: "#161b22"
            border.color: "#30363d"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15; anchors.rightMargin: 15
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: "#3fb950"
                }

                Text {
                    text: "v" + appVersion
                    color: "#8b949e"
                    font.pixelSize: 11; font.family: "Monospace"
                    Layout.fillWidth: true
                }
            }
        }
    }

    Dialog {
        id: addFieldDialog
        title: "Add Field to Search"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        
        ColumnLayout {
            spacing: 10; width: 300
            TextField {
                id: customFieldName
                Layout.fillWidth: true; placeholderText: "Field name (e.g. level)"
                background: Rectangle { color: "#010409"; border.color: "#30363d"; radius: 4 }
                color: "#c9d1d9"
            }
            TextField {
                id: customFieldValue
                Layout.fillWidth: true; placeholderText: "Value (e.g. ERROR)"
                background: Rectangle { color: "#010409"; border.color: "#30363d"; radius: 4 }
                color: "#c9d1d9"
            }
        }

        onAccepted: {
            if (customFieldName.text && customFieldValue.text) {
                let filter = `${customFieldName.text}:"${customFieldValue.text}"`;
                let current = window.searchHeader.searchText;
                if (current && current !== "*") {
                    window.searchHeader.searchText = current + " AND " + filter;
                } else {
                    window.searchHeader.searchText = filter;
                }
                window.refreshLogs(window.searchHeader.searchText);
                customFieldName.clear();
                customFieldValue.clear();
            }
        }
    }

    Connections {
        target: grafanaClient
        function onFacetsReceived(f) { facets = f }
    }
}

