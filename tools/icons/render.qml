import QtQuick
import QtQuick.Window

// Renders the icon SVGs to PNGs (see pack.py):
//     qml tools/icons/render.qml -- <repo>/src/resources <png dir>
Window {
    id: win
    width: 1100
    height: 1100
    visible: true
    color: "transparent"

    readonly property string src: Qt.resolvedUrl("file:///" + Qt.application.arguments[Qt.application.arguments.length - 2])
    readonly property string out: Qt.application.arguments[Qt.application.arguments.length - 1]
    // [file, size, output name]
    readonly property var jobs: [
        ["icon-16.svg", 16, "icon-16.png"],
        ["icon.svg", 24, "icon-24.png"],
        ["icon.svg", 32, "icon-32.png"],
        ["icon.svg", 48, "icon-48.png"],
        ["icon.svg", 64, "icon-64.png"],
        ["icon.svg", 128, "icon-128.png"],
        ["icon.svg", 256, "icon-256.png"],
        ["icon.svg", 512, "icon-512.png"],
        ["icon.svg", 1024, "icon-1024.png"],
        ["icon.svg", 192, "pwa-192.png"],
        ["icon-maskable.svg", 192, "maskable-192.png"],
        ["icon-maskable.svg", 512, "maskable-512.png"]
    ]
    property int done: 0

    Repeater {
        model: win.jobs
        delegate: Image {
            required property var modelData
            width: modelData[1]
            height: modelData[1]
            sourceSize: Qt.size(modelData[1], modelData[1])
            source: win.src + "/" + modelData[0]
            smooth: true
            onStatusChanged: if (status === Image.Ready) Qt.callLater(save)
            function save() {
                grabToImage(result => {
                    result.saveToFile(win.out + "/" + modelData[2])
                    if (++win.done === win.jobs.length) Qt.quit()
                }, Qt.size(modelData[1], modelData[1]))
            }
        }
    }
}
