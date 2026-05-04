import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0d1117"
    border.color: "#30363d"
    border.width: 1

    property var facets: ({})
    property string expandedField: ""
    property string filterText: fieldSearch.text.toLowerCase()

    signal expansionChanged(bool expanded)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12
        
        RowLayout {
            Layout.fillWidth: true
            Controls.Label {
                text: "AVAILABLE FIELDS"
                font.bold: true
                font.pixelSize: 11
                color: "#8b949e"
                Layout.fillWidth: true
            }
            Controls.Button {
                text: "✕ Clear"
                visible: fieldSearch.text !== ""
                font.pixelSize: 11
                contentItem: Text {
                    text: parent.text
                    color: "#f85149"
                    font.pixelSize: 11
                    font.bold: true
                }
                background: null
                onClicked: fieldSearch.clear()
            }
        }

        Controls.TextField {
            id: fieldSearch
            Layout.fillWidth: true
            placeholderText: "Search fields..."
            font.pixelSize: 13
            color: "#c9d1d9"
            padding: 10
            background: Rectangle {
                color: "#010409"
                border.color: fieldSearch.activeFocus ? "#58a6ff" : "#30363d"
                radius: 6
            }
        }

        ListView {
            id: fieldsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            
            model: {
                if (!root.facets) return [];
                let keys = Object.keys(root.facets);
                if (root.filterText !== "") {
                    keys = keys.filter(k => {
                        if (k.toLowerCase().includes(root.filterText)) return true;
                        let values = Object.keys(root.facets[k]);
                        return values.some(v => v.toLowerCase().includes(root.filterText));
                    });
                }
                return keys.sort();
            }

            delegate: Column {
                id: fieldGroup
                width: fieldsList.width
                
                property string fieldName: modelData
                property var fieldValues: root.facets ? root.facets[fieldName] : ({})
                property bool isExpanded: root.expandedField === fieldName || (root.filterText !== "" && !fieldName.toLowerCase().includes(root.filterText))

                Item {
                    width: parent.width
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        color: groupMouse.containsMouse ? "#21262d" : "transparent"
                        radius: 4
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 8
                        Text {
                            text: fieldGroup.isExpanded ? "▼ " + fieldGroup.fieldName : "▶ " + fieldGroup.fieldName
                            color: fieldGroup.isExpanded ? "#58a6ff" : "#c9d1d9"
                            font.pixelSize: 13
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: fieldGroup.fieldValues ? Object.keys(fieldGroup.fieldValues).length : 0
                            color: "#8b949e"
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: groupMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.expandedField === fieldGroup.fieldName) {
                                root.expandedField = "";
                                root.expansionChanged(false);
                            } else {
                                root.expandedField = fieldGroup.fieldName;
                                root.expansionChanged(true);
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: fieldGroup.isExpanded
                    leftPadding: 15
                    topPadding: 2
                    bottomPadding: 5
                    spacing: 1

                    Repeater {
                        model: {
                            if (!fieldGroup.isExpanded || !fieldGroup.fieldValues) return [];
                            let vKeys = Object.keys(fieldGroup.fieldValues);
                            if (root.filterText !== "" && !fieldGroup.fieldName.toLowerCase().includes(root.filterText)) {
                                vKeys = vKeys.filter(v => v.toLowerCase().includes(root.filterText));
                            }
                            return vKeys.sort((a, b) => fieldGroup.fieldValues[b] - fieldGroup.fieldValues[a]).slice(0, 50);
                        }
                        delegate: Controls.ItemDelegate {
                            id: valDelegate
                            width: fieldGroup.width - 20
                            height: 28
                            padding: 5
                            
                            property bool isActive: window.searchHeader.searchText.indexOf(fieldGroup.fieldName + ":\"" + modelData + "\"") !== -1
                            
                            contentItem: RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData
                                    color: valDelegate.isActive ? "#58a6ff" : "#8b949e"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: fieldGroup.fieldValues[modelData] || ""
                                    color: "#484f58"
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: "✕"
                                    color: "#f85149"
                                    font.pixelSize: 10
                                    visible: valDelegate.isActive
                                }
                            }
                            
                            background: Rectangle {
                                color: valDelegate.hovered ? "#161b22" : "transparent"
                                radius: 4
                            }

                            onClicked: {
                                let current = window.searchHeader.searchText;
                                let filter = fieldGroup.fieldName + ":\"" + modelData + "\"";
                                
                                if (current.indexOf(filter) !== -1) {
                                    let parts = current.split(" AND ").filter(p => p.trim() !== filter);
                                    window.searchHeader.searchText = parts.join(" AND ");
                                } else {
                                    if (current && current.trim() !== "" && current !== "*") {
                                        window.searchHeader.searchText = current + " AND " + filter;
                                    } else {
                                        window.searchHeader.searchText = filter;
                                    }
                                }
                                window.refreshLogs(window.searchHeader.searchText);
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: sidebarFooter
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.leftMargin: -10
            Layout.rightMargin: -10
            Layout.bottomMargin: -10
            color: "#161b22"
            border.color: "#30363d"
            border.width: 1

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 15
                    rightMargin: 15
                }
                spacing: 8

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: "#3fb950"
                }

                Text {
                    text: "v" + appVersion
                    color: "#8b949e"
                    font.pixelSize: 11
                    font.family: "Monospace"
                    Layout.fillWidth: true
                }
            }
        }
    }

    Controls.Dialog {
        id: addFieldDialog
        title: "Add Field to Search"
        anchors.centerIn: parent
        modal: true
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        
        ColumnLayout {
            spacing: 10
            width: 300
            Controls.TextField {
                id: customFieldName
                Layout.fillWidth: true
                placeholderText: "Field name (e.g. level)"
                background: Rectangle { color: "#010409"; border.color: "#30363d"; radius: 4 }
                color: "#c9d1d9"
            }
            Controls.TextField {
                id: customFieldValue
                Layout.fillWidth: true
                placeholderText: "Value (e.g. ERROR)"
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
        function onFacetsReceived(f) { root.facets = f }
    }
}

