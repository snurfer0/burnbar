import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// The same reading as Bar, bent into a circle that starts at twelve o'clock.
Item {
    id: ring

    property real value: 0                // percent
    property color tint: Kirigami.Theme.highlightColor
    property real marker: -1              // 0..1, negative hides it
    property real stroke: 3
    property color over: "transparent"    // colour of the arc past the marker

    readonly property real share: Math.min(1, value / 100)
    readonly property bool ahead: marker >= 0 && over.a > 0 && share > marker

    readonly property real radius: (Math.min(width, height) - stroke) / 2

    implicitWidth: 18
    implicitHeight: 18

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(Kirigami.Theme.textColor, 0.14)
            strokeWidth: ring.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.radius; radiusY: ring.radius
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.value > 0 ? ring.tint : "transparent"
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.radius; radiusY: ring.radius
                startAngle: -90
                sweepAngle: 360 * ring.share
                Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        ShapePath {
            strokeColor: ring.ahead ? ring.over : "transparent"
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.radius; radiusY: ring.radius
                startAngle: -90 + 360 * Math.max(0, ring.marker)
                sweepAngle: 360 * Math.max(0, ring.share - ring.marker)
            }
        }
    }
    Item {
        anchors.fill: parent
        visible: ring.marker >= 0
        rotation: 360 * Math.min(1, Math.max(0, ring.marker))
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -1
            width: 2
            height: ring.stroke + 2
            radius: 1
            color: Kirigami.Theme.textColor
            opacity: 0.85
        }
    }
}
