import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    required property var widget          // the PlasmoidItem, for its metadata and updates
    readonly property var meta: widget.meta
    readonly property var updateStatus: widget.updateStatus

    function updateText() {
        if (widget.updating) return "Installing version " + updateStatus.latest + "…"
        if (widget.restartPending) return "Version " + updateStatus.current + " is installed. Restart Plasma or log in again to load it."
        if (updateStatus.error) return updateStatus.error
        if (updateStatus.available) return "Version " + updateStatus.latest + " is available."
        if (updateStatus.checkedAt) return "Up to date. Checked " + Qt.formatDateTime(new Date(updateStatus.checkedAt), "d MMM, hh:mm") + "."
        return "Not checked yet."
    }

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing
        Layout.preferredWidth: 96
        Layout.preferredHeight: 96
        source: "burnbar"
        fallback: "speedometer"
    }
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 2
        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 1
            text: page.meta.name
        }
        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.6
            text: "Version " + page.meta.version
        }
    }
    QQC2.Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: page.meta.description
    }
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        QQC2.Button {
            visible: !!page.meta.website
            text: "Website"
            icon.name: "globe"
            onClicked: Qt.openUrlExternally(page.meta.website)
        }
        QQC2.Button {
            visible: !!page.meta.bugReportUrl
            text: "Report an issue"
            icon.name: "tools-report-bug"
            onClicked: Qt.openUrlExternally(page.meta.bugReportUrl)
        }
    }
    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        opacity: 0.5
    }
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Kirigami.Units.smallSpacing
        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: page.updateText()
            QQC2.ToolTip.visible: hover.hovered && !!page.updateStatus.hint
            QQC2.ToolTip.text: page.updateStatus.hint || ""
            HoverHandler { id: hover }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing
            QQC2.Button {
                text: "Check now"
                icon.name: "view-refresh"
                enabled: !page.widget.updating
                onClicked: page.widget.checkForUpdate(true)
            }
            QQC2.Button {
                visible: !!page.updateStatus.available && !page.widget.restartPending
                enabled: !page.widget.updating
                text: "Update now"
                icon.name: "system-software-update"
                onClicked: page.widget.installUpdate()
            }
            QQC2.Button {
                visible: !!page.updateStatus.page && (!!page.updateStatus.available || page.widget.restartPending)
                text: "What is new"
                icon.name: "documentation"
                onClicked: Qt.openUrlExternally(page.updateStatus.page)
            }
        }
        QQC2.CheckBox {
            Layout.alignment: Qt.AlignHCenter
            text: "Look for updates once a day"
            checked: page.widget.config.checkUpdates
            onToggled: page.widget.config.checkUpdates = checked
        }
        QQC2.CheckBox {
            Layout.alignment: Qt.AlignHCenter
            enabled: page.widget.config.checkUpdates
            text: "Install them automatically"
            checked: page.widget.config.autoUpdate
            onToggled: page.widget.config.autoUpdate = checked
        }
    }
    Kirigami.Separator {
        Layout.fillWidth: true
        opacity: 0.5
    }
    QQC2.Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Kirigami.Units.gridUnit * 29
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.6
        text: page.meta.license + " licence · © 2026 yekgaa\nAn independent project, not affiliated with or endorsed by Anthropic.\nIt reads an endpoint Anthropic does not document, which can change without notice."
    }
}
