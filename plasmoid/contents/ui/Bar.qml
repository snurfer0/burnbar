import QtQuick
import org.kde.kirigami as Kirigami

// A usage bar. The optional marker shows how much of the window's time has passed:
// a fill that is ahead of the marker means usage is running faster than the clock,
// and that stretch is drawn in the `over` colour when one is set.
Item {
    id: bar

    property real value: 0                // percent
    property color tint: Kirigami.Theme.highlightColor
    property real marker: -1              // 0..1, negative hides it
    property color over: "transparent"    // colour of the fill past the marker

    readonly property real fill: Math.max(height, width * Math.min(1, value / 100))
    readonly property bool ahead: marker >= 0 && over.a > 0 && fill > width * marker

    implicitWidth: 30
    implicitHeight: 4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.14)
    }
    Rectangle {
        width: bar.fill
        height: parent.height
        radius: height / 2
        color: bar.ahead ? bar.over : bar.tint
        visible: bar.value > 0
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    Item {
        visible: bar.ahead && bar.value > 0
        width: parent.width * Math.min(1, bar.marker)
        height: parent.height
        clip: true
        Rectangle {
            width: bar.fill
            height: parent.height
            radius: height / 2
            color: bar.tint
        }
    }
    Rectangle {
        visible: bar.marker >= 0
        x: Math.round((parent.width - width) * Math.min(1, bar.marker))
        y: -2
        width: 2
        height: parent.height + 4
        radius: 1
        color: Kirigami.Theme.textColor
        opacity: 0.85
    }
}
