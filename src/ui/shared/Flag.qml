import QtQuick
import QtQuick.Shapes

// A small national flag for a language code: ru, uz, en (the United Kingdom).
// Drawn on a 30×20 grid and scaled, with a hairline frame so white stripes
// stay visible on light backgrounds.
Item {
    id: root

    property string code
    property real flagWidth: 24

    implicitWidth: flagWidth
    implicitHeight: Math.round(flagWidth * 2 / 3)
    Accessible.ignored: true

    Item {
        id: canvas
        width: 30
        height: 20
        scale: root.width / 30
        transformOrigin: Item.TopLeft
        clip: true

        // ── Russia: white, blue, red ──
        Column {
            visible: root.code === "ru"
            Rectangle { width: 30; height: 20 / 3; color: "#ffffff" }
            Rectangle { width: 30; height: 20 / 3; color: "#0039a6" }
            Rectangle { width: 30; height: 20 / 3; color: "#d52b1e" }
        }

        // ── Uzbekistan: blue, white, green with red fimbriations, crescent and stars ──
        Item {
            visible: root.code === "uz"
            anchors.fill: parent
            Rectangle { y: 0; width: 30; height: 6.4; color: "#0099b5" }
            Rectangle { y: 6.4; width: 30; height: 0.6; color: "#ce1126" }
            Rectangle { y: 7; width: 30; height: 6; color: "#ffffff" }
            Rectangle { y: 13; width: 30; height: 0.6; color: "#ce1126" }
            Rectangle { y: 13.6; width: 30; height: 6.4; color: "#1eb53a" }
            // Crescent: a white disc with a blue one over it.
            Rectangle { x: 2.2; y: 1.2; width: 4; height: 4; radius: 2; color: "#ffffff" }
            Rectangle { x: 3.3; y: 1.0; width: 4; height: 4; radius: 2; color: "#0099b5" }
            Repeater {
                model: [[8, 3.6], [10, 3.6], [12, 3.6], [10, 1.8], [12, 1.8], [12, 0.4]]
                delegate: Rectangle {
                    required property var modelData
                    x: modelData[0]; y: modelData[1]
                    width: 0.9; height: 0.9; radius: 0.45
                    color: "#ffffff"
                }
            }
        }

        // ── United Kingdom: Union Jack ──
        Shape {
            visible: root.code === "en"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: "#012169"
                PathRectangle { width: 30; height: 20 } }
            ShapePath { strokeWidth: 4; strokeColor: "#ffffff"; fillColor: "transparent"
                PathSvg { path: "M0 0L30 20M30 0L0 20" } }
            ShapePath { strokeWidth: 1.4; strokeColor: "#c8102e"; fillColor: "transparent"
                PathSvg { path: "M0 0L30 20M30 0L0 20" } }
            ShapePath { strokeWidth: 6; strokeColor: "#ffffff"; fillColor: "transparent"
                PathSvg { path: "M15 0V20M0 10H30" } }
            ShapePath { strokeWidth: 3.4; strokeColor: "#c8102e"; fillColor: "transparent"
                PathSvg { path: "M15 0V20M0 10H30" } }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 2
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.15)
    }
}
