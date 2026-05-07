import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Rectangle {
    id: root
    color: Theme.bgRaised

    property var facets: ({})
    property string expandedField: ""
    property string filterText: fieldSearch.text.toLowerCase()

    signal expansionChanged(bool expanded)

    readonly property int fieldCount: facets ? Object.keys(facets).length : 0

    // Right edge — separator from the table behind.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp3
        spacing: Theme.sp3

        SectionHeader {
            Layout.fillWidth: true
            title: "Available Fields"
            counter: root.fieldCount
            actionVisible: fieldSearch.text !== ""
            actionText: "Clear"
            onActionClicked: fieldSearch.clear()
        }

        AppTextField {
            id: fieldSearch
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            placeholderText: "Search fields…"
        }

        ListView {
            id: fieldsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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
                property int fieldValueCount: fieldValues ? Object.keys(fieldValues).length : 0
                property bool isExpanded: root.expandedField === fieldName || (root.filterText !== "" && !fieldName.toLowerCase().includes(root.filterText))

                Item {
                    width: parent.width
                    height: 30

                    Rectangle {
                        anchors.fill: parent
                        color: groupMouse.containsMouse ? Theme.bgRaised : "transparent"
                        radius: Theme.rSm
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp2
                        anchors.rightMargin: Theme.sp2
                        spacing: Theme.sp2

                        Text {
                            text: fieldGroup.isExpanded ? "▾" : "▸"
                            color: fieldGroup.isExpanded ? Theme.accent : Theme.textMuted
                            font.pixelSize: Theme.fsMd
                            Layout.preferredWidth: 14
                        }
                        Text {
                            text: fieldGroup.fieldName
                            color: fieldGroup.isExpanded ? Theme.accent : Theme.text
                            font.pixelSize: Theme.fsMd
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Badge { text: fieldGroup.fieldValueCount }
                    }
                    MouseArea {
                        id: groupMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
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
                    leftPadding: Theme.sp4
                    topPadding: Theme.sp1
                    bottomPadding: Theme.sp2
                    spacing: 2

                    Repeater {
                        model: {
                            if (!fieldGroup.isExpanded || !fieldGroup.fieldValues) return [];
                            let vKeys = Object.keys(fieldGroup.fieldValues);
                            if (root.filterText !== "" && !fieldGroup.fieldName.toLowerCase().includes(root.filterText)) {
                                vKeys = vKeys.filter(v => v.toLowerCase().includes(root.filterText));
                            }
                            return vKeys.sort((a, b) => fieldGroup.fieldValues[b] - fieldGroup.fieldValues[a]).slice(0, 50);
                        }
                        delegate: Item {
                            id: valItem
                            width: fieldGroup.width - Theme.sp4 - Theme.sp1
                            height: 26

                            property bool isActive: window.searchHeader.searchText.indexOf(fieldGroup.fieldName + ":\"" + modelData + "\"") !== -1

                            Rectangle {
                                anchors.fill: parent
                                color: valItem.isActive
                                    ? Qt.rgba(0.345, 0.654, 1.0, 0.10)
                                    : (valMouse.containsMouse ? Theme.bgRaised : "transparent")
                                radius: Theme.rSm
                                border.color: valItem.isActive ? Theme.accent : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.sp2
                                anchors.rightMargin: Theme.sp2
                                spacing: Theme.sp2

                                Text {
                                    text: modelData
                                    color: valItem.isActive ? Theme.accent : Theme.text
                                    font.pixelSize: Theme.fsSm
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: "Monospace"
                                }
                                Text {
                                    text: fieldGroup.fieldValues[modelData] || ""
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fsXs
                                }
                                Text {
                                    text: "✕"
                                    color: Theme.danger
                                    font.pixelSize: 10
                                    visible: valItem.isActive
                                }
                            }

                            MouseArea {
                                id: valMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.toggleFilter(fieldGroup.fieldName, modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: grafanaClient
        function onFacetsReceived(f) { root.facets = f }
    }
}
