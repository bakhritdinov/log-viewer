import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Dialog {
    id: dialog
    title: "Environment Configuration"
    modal: true

    width: 540
    // No explicit contentHeight binding: on Qt 6.2 (Ubuntu 22.04) binding it
    // to contentItem.implicitHeight produces a polish loop. Dialog derives
    // its own implicitHeight from contentItem.

    onAboutToShow: {
        x = Math.max(0, (parent.width - width) / 2)
        y = Math.max(0, (parent.height - height) / 2)
    }

    background: Rectangle {
        color: Theme.bgRaised
        border.color: Theme.border
        border.width: 1
        radius: Theme.rLg
    }

    contentItem: ColumnLayout {
        id: mainColumn
        spacing: 0

        // Draggable header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "transparent"

            Row {
                anchors.left: parent.left; anchors.leftMargin: Theme.sp5
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2
                Text { text: "⚙"; color: Theme.textMuted; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                Text { text: dialog.title; color: Theme.text; font.pixelSize: Theme.fs2xl; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

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

        TabBar {
            id: bar
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp5
            Layout.rightMargin: Theme.sp5
            Layout.topMargin: Theme.sp4
            background: Rectangle { color: "transparent" }

            TabButton {
                text: "DEV"
                implicitHeight: Theme.hButton + 4
                contentItem: Text {
                    text: parent.text
                    color: bar.currentIndex === 0 ? Theme.accent : Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: Theme.fsMd
                    font.letterSpacing: 0.5
                }
                background: Rectangle {
                    color: bar.currentIndex === 0 ? Theme.bgSubtle : "transparent"
                    border.color: bar.currentIndex === 0 ? Theme.border : "transparent"
                    border.width: 1
                    radius: Theme.rMd
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }
                }
            }
            TabButton {
                text: "PROD"
                implicitHeight: Theme.hButton + 4
                contentItem: Text {
                    text: parent.text
                    color: bar.currentIndex === 1 ? Theme.accent : Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: Theme.fsMd
                    font.letterSpacing: 0.5
                }
                background: Rectangle {
                    color: bar.currentIndex === 1 ? Theme.bgSubtle : "transparent"
                    border.color: bar.currentIndex === 1 ? Theme.border : "transparent"
                    border.width: 1
                    radius: Theme.rMd
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }
                }
            }
        }

        StackLayout {
            id: stack
            currentIndex: bar.currentIndex
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp5
            Layout.rightMargin: Theme.sp5
            Layout.topMargin: Theme.sp3

            EnvSettings { id: devSet; env: "DEV" }
            EnvSettings { id: prodSet; env: "PROD" }
        }

        // Footer
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: "transparent"

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp5
                anchors.rightMargin: Theme.sp5
                spacing: Theme.sp3

                Item { Layout.fillWidth: true }
                SecondaryButton {
                    text: "Cancel"
                    Layout.preferredWidth: 110
                    onClicked: dialog.reject()
                }
                PrimaryButton {
                    text: "Save"
                    Layout.preferredWidth: 110
                    onClicked: { devSet.save(); prodSet.save(); dialog.accept() }
                }
            }
        }
    }

    component EnvSettings : GridLayout {
        property string env: ""
        columns: 2
        rowSpacing: Theme.sp3
        columnSpacing: Theme.sp3
        Layout.fillWidth: true

        function save() {
            if (typeof configManager !== "undefined" && configManager !== null)
                configManager.saveEnv(env, urlF.text, uidF.text, userF.text, passF.text, tokenF.text)
        }

        FieldLabel { text: "Grafana URL" }
        AppTextField {
            id: urlF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            text: (typeof configManager !== "undefined" && configManager !== null) ? configManager.getUrl(env) : ""
            placeholderText: "https://grafana.example.com"
        }
        FieldLabel { text: "Datasource UID" }
        AppTextField {
            id: uidF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            text: (typeof configManager !== "undefined" && configManager !== null) ? configManager.getUid(env) : ""
            placeholderText: "abcd1234efgh"
        }
        FieldLabel { text: "API Token" }
        AppTextField {
            id: tokenF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            text: (typeof configManager !== "undefined" && configManager !== null) ? configManager.getToken(env) : ""
            echoMode: TextField.Password
            placeholderText: "Bearer token (preferred over Basic auth)"
        }
        FieldLabel { text: "Login" }
        AppTextField {
            id: userF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            text: (typeof configManager !== "undefined" && configManager !== null) ? configManager.getUser(env) : ""
            placeholderText: "username (Basic auth fallback)"
        }
        FieldLabel { text: "Password" }
        AppTextField {
            id: passF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            text: (typeof configManager !== "undefined" && configManager !== null) ? configManager.getPass(env) : ""
            echoMode: TextField.Password
            placeholderText: "••••••••"
        }
    }

    component FieldLabel : Label {
        color: Theme.textMuted
        font.pixelSize: Theme.fsSm
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }
}
