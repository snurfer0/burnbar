import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    required property var widget          // the PlasmoidItem; every change to its configuration is written at once
    readonly property var config: widget.config

    Component.onCompleted: levels.setValues(config.warnAt, config.critAt)

    ColumnLayout {
        Kirigami.FormData.label: "Levels:"
        Kirigami.FormData.labelAlignment: Qt.AlignTop
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        spacing: 2

        QQC2.RangeSlider {
            id: levels
            Layout.fillWidth: true
            from: 1
            to: 100
            stepSize: 1
            snapMode: QQC2.RangeSlider.SnapAlways
            // The handles may not cross: amber always starts below red.
            first.onMoved: {
                page.config.warnAt = Math.min(Math.round(first.value), page.config.critAt - 1)
                first.value = page.config.warnAt
            }
            second.onMoved: {
                page.config.critAt = Math.max(Math.round(second.value), page.config.warnAt + 1)
                second.value = page.config.critAt
            }
        }
        // The three zones the two handles cut the scale into.
        Row {
            id: zones
            readonly property real unit: width / 99
            Layout.fillWidth: true
            Layout.leftMargin: levels.first.handle.width / 2
            Layout.rightMargin: levels.first.handle.width / 2
            Layout.preferredHeight: 4
            Rectangle { width: zones.unit * (page.config.warnAt - 1); height: 4; color: page.widget.ok }
            Rectangle { width: zones.unit * (page.config.critAt - page.config.warnAt); height: 4; color: page.widget.warn }
            Rectangle { width: zones.unit * (100 - page.config.critAt); height: 4; color: page.widget.bad }
        }
        QQC2.Label {
            Layout.topMargin: Kirigami.Units.smallSpacing
            textFormat: Text.StyledText
            text: "Amber from <b>" + page.config.warnAt + "%</b> used · red from <b>" + page.config.critAt + "%</b>"
        }
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        Kirigami.FormData.label: "Pace:"
        text: "Mark usage that will hit the limit before it resets"
        checked: page.config.warnOnPace
        onToggled: page.config.warnOnPace = checked
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        Kirigami.FormData.label: "Notifications:"
        text: "When a limit crosses the amber or red level"
        checked: page.config.notify
        onToggled: page.config.notify = checked
    }
    QQC2.Button {
        text: "Send a test notification"
        icon.name: "notifications"
        onClicked: page.widget.notify("Session limit at " + page.config.warnAt + "%", "Resets in 1h 20m · full in 35m")
    }
}
