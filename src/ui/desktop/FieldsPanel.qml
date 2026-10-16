import QtQuick
import QtQuick.Layouts
import LogViewer.App
import LogViewer.Ui

// Docked field list: never covers the logs; collapses to a thin rail.
Rectangle {
    id: root

    property bool expanded: true          // the user's choice (remembered)
    property bool squeezed: false         // too little room for the results: collapsed for now
    property bool peeked: false           // opened from the rail while squeezed
    readonly property bool open: expanded && (!squeezed || peeked)
    onSqueezedChanged: if (!squeezed) peeked = false

    implicitWidth: open ? 248 : 36
    color: Theme.bg

    Rectangle { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; width: 1; color: Theme.borderMuted }

    // Collapsed: a rail; a click anywhere on it brings the fields back.
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 1
        visible: !root.open
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Show fields")
        onClicked: { root.expanded = true; root.peeked = root.squeezed }
        Rectangle { anchors.fill: parent; color: parent.containsMouse ? Theme.surface : "transparent" }
        IconButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8
            implicitWidth: 24
            implicitHeight: 24
            iconName: "chevronRight"
            label: qsTr("Show fields")
            onClicked: { root.expanded = true; root.peeked = root.squeezed }
        }
        // Vertical label: the box holds the rotated text's length.
        Item {
            y: 44
            width: parent.width
            height: railLabel.implicitWidth
            Text {
                id: railLabel
                anchors.centerIn: parent
                rotation: -90
                text: qsTr("Fields · %1").arg(Session.fieldCount).toUpperCase()
                font.family: Theme.sans
                font.pixelSize: Theme.fontXs
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                color: Theme.textMuted
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: 1
        visible: root.open
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
                onClicked: { root.expanded = false; root.peeked = false }
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
            Layout.fillHeight: count > 0   // empty: the messages below take the room
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            model: Session.facets
            onToggleExpanded: field => Session.toggleFacetExpanded(field)
            onValueActivated: (field, value, exclude) => Session.toggleFilter(field, value, exclude)
        }
        // The filter matches nothing.
        Text {
            Layout.fillWidth: true
            Layout.margins: 16
            visible: Session.facets.count === 0 && Session.facetFilterText !== ""
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            text: qsTr("No fields or values with “%1”.").arg(Session.facetFilterText)
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
        AppButton {
            Layout.leftMargin: 12
            visible: Session.facets.count === 0 && Session.facetFilterText !== ""
            variant: "link"
            text: qsTr("Clear")
            onClicked: Session.facetFilterText = ""
        }
        // First batch on its way.
        Column {
            Layout.fillWidth: true
            Layout.margins: 16
            visible: Session.facets.count === 0 && Session.facetFilterText === "" && Session.loading
            spacing: 14
            Repeater {
                model: [0.6, 0.45, 0.7, 0.5, 0.65]
                delegate: Rectangle {
                    required property real modelData
                    width: parent.width * modelData
                    height: 10
                    radius: Theme.radiusSm
                    color: Theme.subtle
                }
            }
        }
        Item { Layout.fillHeight: Session.facets.count === 0 }
    }
}
