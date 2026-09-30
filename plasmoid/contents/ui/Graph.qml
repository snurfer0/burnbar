import QtQuick
import org.kde.kirigami as Kirigami

// Usage across one window: the recorded line up to now, and a dashed diagonal for an even pace
// that would land on exactly 100% at the reset. A line above the diagonal is burning too fast.
Canvas {
    id: graph

    property var samples: []              // [[unix seconds, percent], …], oldest first
    property real start: 0                // window start, unix seconds
    property real end: 1                  // window end, unix seconds
    property color tint: Kirigami.Theme.highlightColor
    readonly property color ink: Kirigami.Theme.textColor

    implicitHeight: 44

    onSamplesChanged: requestPaint()
    onStartChanged: requestPaint()
    onEndChanged: requestPaint()
    onTintChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (end <= start || width <= 0) return
        const top = Math.max(100, ...samples.map(sample => sample[1]))
        const px = t => (Math.min(end, Math.max(start, t)) - start) / (end - start) * width
        const py = p => height - 1 - p / top * (height - 2)

        ctx.lineWidth = 1
        ctx.strokeStyle = Qt.alpha(ink, 0.12)
        ctx.beginPath()
        ctx.moveTo(0, height - 0.5)
        ctx.lineTo(width, height - 0.5)
        ctx.stroke()

        ctx.strokeStyle = Qt.alpha(ink, 0.28)
        ctx.setLineDash([3, 3])
        ctx.beginPath()
        ctx.moveTo(0, py(0))
        ctx.lineTo(width, py(100))
        ctx.stroke()
        ctx.setLineDash([])

        if (samples.length < 2) return
        ctx.beginPath()
        samples.forEach((sample, index) => {
            if (index === 0) ctx.moveTo(px(sample[0]), py(sample[1]))
            else ctx.lineTo(px(sample[0]), py(sample[1]))
        })
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.strokeStyle = tint
        ctx.stroke()

        ctx.lineTo(px(samples[samples.length - 1][0]), height)
        ctx.lineTo(px(samples[0][0]), height)
        ctx.closePath()
        ctx.fillStyle = Qt.alpha(tint, 0.16)
        ctx.fill()
    }
}
