import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: dialog
    title: "⚙ Environment Configuration"
    modal: true
    
    width: 500
    contentHeight: mainColumn.implicitHeight

    onAboutToShow: {
        x = Math.max(0, (parent.width - width) / 2)
        y = Math.max(0, (parent.height - height) / 2)
    }

    background: Rectangle {
        color: "#161b22"
        border.color: "#30363d"
        radius: 12
        border.width: 1
    }

    contentItem: ColumnLayout {
        id: mainColumn
        spacing: 0
        
        // Draggable Header Area
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "transparent"
            
            Label {
                text: dialog.title
                font.pixelSize: 18; font.bold: true
                anchors.fill: parent
                padding: 20
                color: "#c9d1d9"
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                property point lastMousePos
                onPressed: (mouse) => { lastMousePos = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: (mouse) => {
                    let delta = Qt.point(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y)
                    dialog.x += delta.x
                    dialog.y += delta.y
                }
            }
        }

        // TabBar Area (Not covered by MouseArea)
        TabBar {
            id: bar
            Layout.fillWidth: true
            Layout.leftMargin: 20; Layout.rightMargin: 20
            Layout.bottomMargin: 10
            background: Rectangle { color: "transparent" }
            
            TabButton {
                text: "🛠 DEV"
                implicitHeight: 32
                contentItem: Text { text: parent.text; color: bar.currentIndex === 0 ? "#58a6ff" : "#8b949e"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true }
                background: Rectangle { color: bar.currentIndex === 0 ? "#21262d" : "transparent"; border.color: bar.currentIndex === 0 ? "#30363d" : "transparent"; radius: 6 }
            }
            TabButton {
                text: "🚀 PROD"
                implicitHeight: 32
                contentItem: Text { text: parent.text; color: bar.currentIndex === 1 ? "#58a6ff" : "#8b949e"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true }
                background: Rectangle { color: bar.currentIndex === 1 ? "#21262d" : "transparent"; border.color: bar.currentIndex === 1 ? "#30363d" : "transparent"; radius: 6 }
            }
        }

        // Body
        StackLayout {
            id: stack
            currentIndex: bar.currentIndex
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.topMargin: 10
            
            EnvSettings { id: devSet; env: "DEV" }
            EnvSettings { id: prodSet; env: "PROD" }
        }

        // Footer
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 20; Layout.topMargin: 0
            spacing: 12
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"; onClicked: dialog.reject()
                contentItem: Text { text: parent.text; color: "#c9d1d9"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.down ? "#30363d" : "#21262d"; border.color: "#30363d"; radius: 6; implicitWidth: 110; implicitHeight: 38 }
            }
            Button {
                text: "💾 Save All"
                onClicked: { devSet.save(); prodSet.save(); dialog.accept() }
                contentItem: Text { text: parent.text; color: "#ffffff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.down ? "#2ea043" : "#238636"; radius: 6; implicitWidth: 110; implicitHeight: 38 }
            }
        }
    }

    component EnvSettings : GridLayout {
        property string env: ""
        columns: 2; rowSpacing: 15; columnSpacing: 15
        Layout.fillWidth: true
        function save() { configManager.saveEnv(env, urlF.text, uidF.text, userF.text, passF.text, nsF.text, appF.text) }
        Label { text: "URL:"; color: "#8b949e"; font.pixelSize: 13; Layout.alignment: Qt.AlignRight }
        TextField {
            id: urlF; Layout.fillWidth: true; text: configManager.getUrl(env)
            color: "#c9d1d9"; font.pixelSize: 13; padding: 10
            background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6 }
        }
        Label { text: "UID:"; color: "#8b949e"; font.pixelSize: 13; Layout.alignment: Qt.AlignRight }
        TextField {
            id: uidF; Layout.fillWidth: true; text: configManager.getUid(env)
            color: "#c9d1d9"; font.pixelSize: 13; padding: 10
            background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6 }
        }
        Label { text: "Login:"; color: "#8b949e"; font.pixelSize: 13; Layout.alignment: Qt.AlignRight }
        TextField {
            id: userF; Layout.fillWidth: true; text: configManager.getUser(env)
            color: "#c9d1d9"; font.pixelSize: 13; padding: 10
            background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6 }
        }
        Label { text: "Password:"; color: "#8b949e"; font.pixelSize: 13; Layout.alignment: Qt.AlignRight }
        TextField {
            id: passF; Layout.fillWidth: true; text: configManager.getPass(env); echoMode: TextField.Password
            color: "#c9d1d9"; font.pixelSize: 13; padding: 10
            background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6 }
        }
        Label { text: "NS Label:"; color: "#8b949e"; font.pixelSize: 13; Layout.alignment: Qt.AlignRight }
        TextField {
            id: nsF; Layout.fillWidth: true; text: configManager.getNsLabel(env)
            color: "#c9d1d9"; font.pixelSize: 13; padding: 10
            placeholderText: "_namespace"
            background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6 }
        }
        Label { text: "App Label:"; color: "#8b949e"; font.pixelSize: 13; Layout.alignment: Qt.AlignRight }
        TextField {
            id: appF; Layout.fillWidth: true; text: configManager.getAppLabel(env)
            color: "#c9d1d9"; font.pixelSize: 13; padding: 10
            placeholderText: "_appName"
            background: Rectangle { color: "#0d1117"; border.color: "#30363d"; radius: 6 }
        }
    }
}
