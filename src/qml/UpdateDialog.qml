import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: updateDialog
    title: "Update Available"
    modal: true
    width: 350
    height: 200
    
    anchors.centerIn: Overlay.overlay

    background: Rectangle {
        color: "#161b22"
        border.color: "#30363d"
        radius: 12
    }

    contentItem: ColumnLayout {
        spacing: 20
        anchors.margins: 20

        ColumnLayout {
            spacing: 5
            Layout.fillWidth: true
            Label {
                text: "✨ A new version is ready!"
                color: "#58a6ff"
                font.pixelSize: 18
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: "Version " + updateManager.latestVersion + " is now available."
                color: "#c9d1d9"
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
            }
        }

        RowLayout {
            spacing: 12
            Layout.alignment: Qt.AlignHCenter
            
            Button {
                text: "Later"
                onClicked: updateDialog.close()
                contentItem: Text { text: parent.text; color: "#c9d1d9"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.down ? "#30363d" : "#21262d"; border.color: "#30363d"; radius: 6; implicitWidth: 100; implicitHeight: 38 }
            }
            
            Button {
                text: "Update Now"
                onClicked: {
                    updateManager.downloadLatest();
                    updateDialog.close();
                }
                contentItem: Text { text: parent.text; color: "#ffffff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.down ? "#2ea043" : "#238636"; radius: 6; implicitWidth: 120; implicitHeight: 38 }
            }
        }
    }
}
