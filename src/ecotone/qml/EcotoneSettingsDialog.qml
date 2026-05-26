import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

Dialog {
    id: dialog
    title: qsTr("Ecotone — Database Configuration")
    modal: true
    width: 560

    // Emitted after Save so the parent window can reload using the now-active env.
    signal saved()

    onAboutToShow: {
        x = Math.max(0, (parent.width  - width)  / 2)
        y = Math.max(0, (parent.height - height) / 2)
        // Open on the currently active environment by default.
        if (typeof configManager !== "undefined" && configManager !== null) {
            bar.currentIndex = configManager.currentEnv === "PROD" ? 1 : 0
        }
        devSet.reload()
        prodSet.reload()
        devSet.testStatus = ""
        prodSet.testStatus = ""
    }

    background: Rectangle {
        color: Theme.bgRaised
        border.color: Theme.border
        border.width: 1
        radius: Theme.rLg
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header bar with title.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp5
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2
                Text { text: "⚙"; color: Theme.textMuted; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                Text { text: dialog.title; color: Theme.text; font.pixelSize: Theme.fs2xl; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
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

            DbSettings { id: devSet;  env: "DEV"  }
            DbSettings { id: prodSet; env: "PROD" }
        }

        // Padding row between Test Connection and footer so they don't
        // visually collide.
        Item { Layout.preferredHeight: Theme.sp4 }

        // Footer with Cancel / Save (Save also marks the active env).
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

                Label {
                    text: qsTr("Save will set active env to: %1").arg(bar.currentIndex === 0 ? "DEV" : "PROD")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsSm
                }
                Item { Layout.fillWidth: true }
                SecondaryButton {
                    text: qsTr("Cancel")
                    Layout.preferredWidth: 110
                    onClicked: dialog.reject()
                }
                PrimaryButton {
                    text: qsTr("Save")
                    Layout.preferredWidth: 110
                    onClicked: {
                        devSet.save()
                        prodSet.save()
                        if (typeof configManager !== "undefined" && configManager !== null) {
                            configManager.currentEnv = bar.currentIndex === 0 ? "DEV" : "PROD"
                        }
                        dialog.saved()
                        dialog.accept()
                    }
                }
            }
        }
    }

    // Per-environment connection form.
    component DbSettings : GridLayout {
        property string env: ""
        property string testStatus: ""
        property color  testColor: Theme.textMuted

        columns: 2
        rowSpacing: Theme.sp3
        columnSpacing: Theme.sp3
        Layout.fillWidth: true

        function reload() {
            if (typeof ecotoneConfig === "undefined" || ecotoneConfig === null) return
            hostF.text = ecotoneConfig.host(env)
            portF.text = String(ecotoneConfig.port(env))
            dbF.text   = ecotoneConfig.database(env)
            userF.text = ecotoneConfig.user(env)
            passF.text = ecotoneConfig.password(env)
        }

        function save() {
            if (typeof ecotoneConfig === "undefined" || ecotoneConfig === null) return
            ecotoneConfig.save(env,
                hostF.text,
                parseInt(portF.text || "5432", 10),
                dbF.text,
                userF.text,
                passF.text)
        }

        FieldLabel { text: qsTr("Host") }
        AppTextField {
            id: hostF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            placeholderText: "localhost"
        }

        FieldLabel { text: qsTr("Port") }
        AppTextField {
            id: portF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            placeholderText: "5432"
            validator: IntValidator { bottom: 1; top: 65535 }
        }

        FieldLabel { text: qsTr("Database") }
        AppTextField {
            id: dbF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            placeholderText: "ecotone"
        }

        FieldLabel { text: qsTr("User") }
        AppTextField {
            id: userF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            placeholderText: "username"
        }

        FieldLabel { text: qsTr("Password") }
        AppTextField {
            id: passF
            Layout.fillWidth: true
            implicitHeight: Theme.hInput
            echoMode: TextField.Password
            placeholderText: "••••••••"
        }

        // Test row spans both columns.
        Item { width: 1 }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            SecondaryButton {
                text: qsTr("Test Connection")
                onClicked: {
                    testStatus = qsTr("Testing…")
                    testColor = Theme.textMuted
                    if (typeof ecotoneClient !== "undefined" && ecotoneClient !== null) {
                        ecotoneClient.testConnection(
                            hostF.text,
                            parseInt(portF.text || "5432", 10),
                            dbF.text, userF.text, passF.text)
                    }
                }
            }
            Label {
                text: testStatus
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: testColor
                font.pixelSize: Theme.fsSm
                elide: Text.ElideRight
            }
        }

        Connections {
            target: typeof ecotoneClient !== "undefined" ? ecotoneClient : null
            ignoreUnknownSignals: true
            function onTestConnectionResult(ok, reason) {
                if (!dialog.visible || stack.currentIndex !== (env === "DEV" ? 0 : 1)) return
                if (ok) {
                    testStatus = qsTr("Connection OK")
                    testColor = Theme.success
                } else {
                    testStatus = reason
                    testColor = Theme.danger
                }
            }
        }
    }

    component FieldLabel : Label {
        color: Theme.textMuted
        font.pixelSize: Theme.fsSm
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }
}
