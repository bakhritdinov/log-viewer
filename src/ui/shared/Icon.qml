import QtQuick
import QtQuick.Shapes

// A stroke icon from Icons.paths, recoloured by `color`. Decorative by default;
// give it `Accessible.name` (and set `decorative: false`) when it carries meaning.
Item {
    id: root

    property string name
    property color color: Theme.text
    property real size: 16
    property real strokeWidth: 2
    property bool decorative: true

    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.Graphic
    Accessible.ignored: decorative

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        visible: root.name !== ""

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.paths[root.name] ?? "" }
        }
    }
}
