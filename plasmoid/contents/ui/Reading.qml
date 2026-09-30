import QtQuick
import org.kde.kirigami as Kirigami

// One limit as it appears in the panel: caption, bar or ring, percentage, optional countdown.
Row {
    id: reading

    property string caption: ""
    property real value: 0                // percent, already turned into "left" if that is shown
    property string style: "bar"          // bar | ring | text
    property color tint: Kirigami.Theme.highlightColor
    property color over: "transparent"
    property color ink: Kirigami.Theme.textColor
    property real marker: -1
    property string countdown: ""

    spacing: 5

    Quiet {
        anchors.baseline: number.baseline
        text: reading.caption
    }
    Bar {
        visible: reading.style === "bar"
        anchors.verticalCenter: parent.verticalCenter
        value: reading.value
        tint: reading.tint
        over: reading.over
        marker: reading.marker
    }
    Ring {
        visible: reading.style === "ring"
        anchors.verticalCenter: parent.verticalCenter
        value: reading.value
        tint: reading.tint
        over: reading.over
        marker: reading.marker
    }
    Text {
        id: number
        // A fixed slot, so the panel does not shift when 9% becomes 10%.
        width: slot.advanceWidth
        horizontalAlignment: Text.AlignRight
        text: Math.round(reading.value) + "%"
        color: reading.ink
        font: slot.font
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    Quiet {
        visible: reading.countdown !== ""
        anchors.baseline: number.baseline
        text: reading.countdown
    }
    TextMetrics {
        id: slot
        text: "100%"
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 13
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }
}
