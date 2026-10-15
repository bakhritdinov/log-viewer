import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Docked field list: never covers the logs; collapses to a thin rail.
Rectangle {
    id: root

    property bool expanded: true

    implicitWidth: expanded ? 248 : 36
    color: Theme.bg

    Rectangle { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; width: 1; color: Theme.borderMuted }

    IconButton {
        visible: !root.expanded
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        iconName: "chevronRight"
        label: qsTr("Show fields")
        onClicked: root.expanded = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: 1
        visible: root.expanded
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.bottomMargin: 8
            SectionLabel { Layout.fillWidth: true; text: qsTr("Fields · %1").arg(Session.fieldCount) }
            IconButton {
                implicitWidth: 24
                iconName: "chevronLeft"
                label: qsTr("Hide fields")
                onClicked: root.expanded = false
            }
        }
        AppTextField {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 8
            implicitHeight: 30
            placeholderText: qsTr("Field, value or key:value")
            Accessible.name: qsTr("Search fields")
            text: Session.facetFilterText
            onTextEdited: Session.facetFilterText = text
        }
        // Same side margins as the filter field: highlights line up with it.
        FacetList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            model: Session.facets
            onToggleExpanded: field => Session.toggleFacetExpanded(field)
            onValueActivated: (field, value, exclude) => Session.toggleFilter(field, value, exclude)
        }
    }
}
