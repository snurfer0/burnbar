import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property var config                   // the widget's configuration; every change is written at once

    FolderDialog {
        id: folderDialog
        title: "Claude Code folder"
        onAccepted: page.config.claudeFolder = decodeURIComponent(selectedFolder.toString().replace("file://", ""))
    }

    QQC2.ComboBox {
        Kirigami.FormData.label: "Refresh every:"
        textRole: "text"
        valueRole: "value"
        model: [
            { text: "Minute", value: 60 },
            { text: "2 minutes", value: 120 },
            { text: "5 minutes", value: 300 },
            { text: "15 minutes", value: 900 },
            { text: "30 minutes", value: 1800 }
        ]
        Component.onCompleted: {
            // An interval set by an older version may not be one of the choices: take the nearest.
            let nearest = 0
            model.forEach((choice, index) => {
                if (Math.abs(choice.value - page.config.interval) < Math.abs(model[nearest].value - page.config.interval))
                    nearest = index
            })
            currentIndex = nearest
        }
        onActivated: page.config.interval = currentValue
    }
    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        text: "Applies while Claude Code is in use. When it is idle, the limits are fetched every 15 minutes at most. Anthropic blocks usage checks for a while when they come more often than about once a minute."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: "Claude folder:"
        QQC2.TextField {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            placeholderText: "~/.claude"
            text: page.config.claudeFolder
            // Applied when editing ends, not on every keystroke, so no half-typed path is tried.
            onEditingFinished: page.config.claudeFolder = text.trim()
        }
        QQC2.Button {
            icon.name: "document-open-folder"
            onClicked: folderDialog.open()
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: "Choose a folder"
        }
    }
    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        text: "Where Claude Code keeps its login. Leave empty unless you use a second account or a custom CLAUDE_CONFIG_DIR."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
