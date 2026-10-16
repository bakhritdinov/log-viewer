import QtQuick

// The app icon (src/resources/icon.svg) drawn in QML: crisp at any size and
// scale, and independent of the executable's resources.
Item {
    id: root

    property real size: 24

    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.Graphic
    Accessible.name: "LogViewer"

    // Drawn on the icon's 512 grid and scaled down.
    Item {
        width: 512
        height: 512
        scale: root.size / 512
        transformOrigin: Item.TopLeft

        Rectangle {
            x: 16; y: 16; width: 480; height: 480
            radius: 108
            gradient: Gradient {
                GradientStop { position: 0; color: "#1c2129" }
                GradientStop { position: 1; color: "#0d1117" }
            }
            // A heavier frame on small sizes, so the tile does not melt into
            // a dark bar.
            border.width: root.size < 40 ? 24 : 3
            border.color: "#30363d"
        }
        Repeater {
            model: [
                { y: 104, stripe: "#f85149", bar: "#f0f6fc", length: 264 },
                { y: 190, stripe: "#d29922", bar: "#8b949e", length: 200 },
                { y: 276, stripe: "#58a6ff", bar: "#8b949e", length: 236 },
                { y: 362, stripe: "#58a6ff", bar: "#8b949e", length: 160 },
            ]
            delegate: Item {
                id: line
                required property var modelData
                Rectangle { x: 88; y: line.modelData.y; width: 48; height: 64; radius: 12; color: line.modelData.stripe }
                Rectangle { x: 160; y: line.modelData.y + 10; width: line.modelData.length; height: 44; radius: 22; color: line.modelData.bar }
            }
        }
    }
}
