import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    id: page

    property var config                   // the widget's configuration; every change is written at once

    Row {
        Kirigami.FormData.label: "Style:"
        spacing: 0
        Repeater {
            model: [
                { text: "Bar", value: "bar" },
                { text: "Ring", value: "ring" },
                { text: "Text only", value: "text" }
            ]
            QQC2.Button {
                required property var modelData
                text: modelData.text
                checkable: true
                autoExclusive: true
                checked: page.config.style === modelData.value
                onClicked: page.config.style = modelData.value
            }
        }
    }
    Row {
        Kirigami.FormData.label: "Colour:"
        spacing: Kirigami.Units.smallSpacing + 2
        Repeater {
            // "" follows the theme's accent colour
            model: ["", "#d97757", "#4ade80", "#38bdf8", "#c084fc", "#f472b6", "#e5e7eb"]
            Rectangle {
                id: swatch
                required property string modelData
                readonly property bool chosen: page.config.accent.toLowerCase() === modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: modelData || Kirigami.Theme.highlightColor
                scale: hover.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 100 } }

                // Selection ring, set off from the swatch so it reads on any colour.
                Rectangle {
                    anchors.centerIn: parent
                    width: 32; height: 32; radius: 16
                    color: "transparent"
                    border.width: 2
                    border.color: Kirigami.Theme.textColor
                    visible: swatch.chosen
                }
                QQC2.Label {
                    anchors.centerIn: parent
                    visible: swatch.modelData === ""
                    text: "A"
                    font.bold: true
                    color: Kirigami.Theme.highlightedTextColor
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.config.accent = swatch.modelData
                }
                QQC2.ToolTip.visible: hover.containsMouse && swatch.modelData === ""
                QQC2.ToolTip.text: "Follow the theme's accent colour"
            }
        }
        Item { width: Kirigami.Units.smallSpacing; height: 1 }
        KQuickControls.ColorButton {
            anchors.verticalCenter: parent.verticalCenter
            color: page.config.accent ? page.config.accent : Kirigami.Theme.highlightColor
            onAccepted: color => page.config.accent = color.toString()
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: "Pick any colour"
        }
    }
    QQC2.CheckBox {
        Kirigami.FormData.label: "Show:"
        text: "Time marker"
        checked: page.config.showPace
        onToggled: page.config.showPace = checked
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        QQC2.ToolTip.text: "A tick for how much of the window's time has passed.\nUsage ahead of the tick is running faster than the clock."
    }
    QQC2.CheckBox {
        text: "Time until the reset"
        checked: page.config.showCountdown
        onToggled: page.config.showCountdown = checked
    }
    QQC2.CheckBox {
        text: "What is left, not what is used"
        checked: page.config.showRemaining
        onToggled: page.config.showRemaining = checked
    }

    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Limits in the panel"
    }
    QQC2.RadioButton {
        text: "The ones I choose"
        checked: !page.config.focus
        onToggled: if (checked) page.config.focus = false
    }
    Column {
        leftPadding: Kirigami.Units.gridUnit
        enabled: !page.config.focus
        QQC2.CheckBox {
            text: "Session (5 hours)"
            checked: page.config.showSession
            onToggled: page.config.showSession = checked
        }
        QQC2.CheckBox {
            text: "Weekly"
            checked: page.config.showWeekly
            onToggled: page.config.showWeekly = checked
        }
        QQC2.CheckBox {
            text: "Weekly per model"
            checked: page.config.showModels
            onToggled: page.config.showModels = checked
        }
    }
    QQC2.RadioButton {
        text: "Only the one closest to running out"
        checked: page.config.focus
        onToggled: if (checked) page.config.focus = true
    }

    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Popup"
    }
    QQC2.CheckBox {
        text: "Usage graph under each limit"
        checked: page.config.showGraph
        onToggled: page.config.showGraph = checked
    }
}
