import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notification
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string codeDir: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace("file://", ""))
    readonly property var config: Plasmoid.configuration
    readonly property var meta: Plasmoid.metaData
    readonly property string burnbar: "sh " + quote(codeDir + "run.sh")
    readonly property string command: burnbar + " --json"
        + (config.claudeFolder ? " --config-dir " + quote(config.claudeFolder) : "")

    property var snapshot: ({ ok: false, loading: true, limits: [], breakdown: [] })
    property bool refreshing: false
    // What `burnbar update` last said; see src/update.ts.
    property var updateStatus: ({})
    property bool updating: false
    // Tried once per version, so a failing install is not repeated every hour.
    property string triedUpdate: ""
    // The files on disk are newer than what plasmashell loaded: an update waits for a restart.
    readonly property bool restartPending: !!updateStatus.current && updateStatus.current !== meta.version
    property double now: Date.now()
    // Anthropic answers 429 to checks a minute apart, since Claude Code reads the same limits.
    readonly property int interval: Math.max(120, config.interval)

    readonly property var panelLimits: {
        const limits = snapshot.limits
        if (config.focus)
            return limits.length ? [limits.reduce((worst, limit) => limit.percent > worst.percent ? limit : worst)] : []
        return limits.filter(limit =>
            limit.id === "session" ? config.showSession
            : limit.id === "weekly_all" ? config.showWeekly
            : config.showModels)
    }

    readonly property color ok: config.accent ? config.accent : Kirigami.Theme.highlightColor
    readonly property color warn: "#fbbf24"
    readonly property color bad: "#f87171"

    function quote(text) {
        return "'" + text.replace(/'/g, "'\\''") + "'"
    }
    function shown(limit) {
        return config.showRemaining ? Math.max(0, 100 - limit.percent) : limit.percent
    }
    // 0 fine, 1 past the warning level, 2 nearly used up
    function level(limit) {
        return limit.percent >= config.critAt ? 2 : limit.percent >= config.warnAt ? 1 : 0
    }
    function tint(limit) {
        return [ok, warn, bad][level(limit)]
    }
    // Usage that will reach the limit before the reset is ahead of pace.
    function ahead(limit) {
        return config.warnOnPace && !!limit.hitsAt
    }
    // Colour for the stretch of a bar or ring that is past the time marker.
    function over(limit) {
        return ahead(limit) && !config.showRemaining && level(limit) === 0 ? warn : "transparent"
    }
    function ink(limit) {
        if (level(limit) > 0) return tint(limit)
        return ahead(limit) ? warn : Kirigami.Theme.textColor
    }
    function caption(limit) {
        if (limit.id === "session") return "5H"
        if (limit.id === "weekly_all") return "7D"
        return limit.label.replace("Weekly ", "").toUpperCase()
    }
    // Where the clock stands in the window, 0..1, on the same scale as the shown value;
    // -1 when unknown or switched off.
    function elapsed(limit) {
        if (!config.showPace || !limit.resetsAt || !limit.windowHours) return -1
        const left = Math.min(1, Math.max(0, (Date.parse(limit.resetsAt) - now) / (limit.windowHours * 3600000)))
        return config.showRemaining ? left : 1 - left
    }
    // A graph of a window that has barely started is an empty box.
    function hasGraph(limit) {
        const history = limit.history
        return config.showGraph && history.length > 1
            && history[history.length - 1][0] - history[0][0] >= limit.windowHours * 180
    }
    function span(ms) {
        const minutes = Math.max(0, Math.round(ms / 60000))
        const days = Math.floor(minutes / 1440)
        const hours = Math.floor((minutes % 1440) / 60)
        if (days) return days + "d " + hours + "h"
        return hours ? hours + "h " + (minutes % 60) + "m" : minutes + "m"
    }
    function until(iso) {
        return span(Date.parse(iso) - now)
    }
    function resetText(limit) {
        if (!limit.resetsAt) return ""
        return Date.parse(limit.resetsAt) <= now ? "Reset due" : "Resets in " + until(limit.resetsAt)
    }
    function forecast(limit) {
        if (limit.hitsAt) return Date.parse(limit.hitsAt) <= now ? "full any moment" : "full in " + until(limit.hitsAt)
        return limit.projected === null || limit.projected === undefined ? "" : "on pace for " + limit.projected + "%"
    }

    // The error in one line: what is wrong, and when burnbar tries again if it is waiting.
    function problem() {
        if (!snapshot.error) return ""
        const waiting = snapshot.retryAt && Date.parse(snapshot.retryAt) > now
        return snapshot.error + (waiting ? " · next try in " + until(snapshot.retryAt) : "")
    }
    function updated() {
        if (!snapshot.fetchedAt) return ""
        const age = now - Date.parse(snapshot.fetchedAt)
        return age < 60000 ? "Updated just now" : "Updated " + span(age) + " ago"
    }
    function resetOffer() {
        const offer = snapshot.reset
        if (!offer) return ""
        return offer.left + (offer.left === 1 ? " limit reset" : " limit resets") + " available"
            + (offer.endsAt ? " until " + Qt.formatDate(new Date(offer.endsAt), "d MMM") : "")
            + ". Use it with /limit-reset in Claude Code."
    }

    function take(data) {
        let next
        try {
            next = JSON.parse(data["stdout"])
        } catch (e) {
            next = { ok: false, error: (data["stderr"] || "").trim() || "burnbar returned no data" }
        }
        next.limits = (next.limits || []).map(limit => Object.assign({ history: [], windowHours: 0 }, limit))
        next.breakdown = next.breakdown || []
        snapshot = next
        now = Date.now()
        announce()
    }
    // Runs a command once and hands its output to `done`. The timestamp keeps two runs of
    // the same command apart, since the data engine knows a source by its text.
    function run(line, done) {
        const source = line + " #" + Date.now()
        shell.pending[source] = done
        shell.connectSource(source)
    }
    function refresh() {
        if (refreshing) return
        refreshing = true
        run(command + " --max-age 0", data => {
            refreshing = false
            take(data)
        })
    }

    function checkForUpdate(force) {
        if (updating) return
        run(burnbar + " update --check --json" + (force ? " --max-age 0" : ""), data => {
            try { updateStatus = JSON.parse(data["stdout"]) } catch (e) { return }
            if (!updateStatus.available) return
            if (config.autoUpdate) {
                if (updateStatus.latest !== triedUpdate) installUpdate()
            } else if (updateStatus.latest !== config.announcedUpdate) {
                config.announcedUpdate = updateStatus.latest
                notify("Burnbar " + updateStatus.latest + " is available", "Open Burnbar and press Update to install it.")
            }
        })
    }
    function installUpdate() {
        if (updating) return
        updating = true
        triedUpdate = updateStatus.latest || ""
        run(burnbar + " update --json", data => {
            updating = false
            try { updateStatus = JSON.parse(data["stdout"]) } catch (e) { return }
            if (updateStatus.installed) {
                updateStatus = Object.assign({}, updateStatus, { current: updateStatus.installed })
                notify("Burnbar updated to " + updateStatus.installed, "Restart Plasma or log in again to load it.")
            }
        })
    }

    function notify(title, text) {
        alert.createObject(root, { title: title, text: text }).sendEvent()
    }

    // One notification per limit, level and window: the announced level is kept in the
    // configuration so a plasmashell restart does not repeat it.
    function announce() {
        if (!config.notify || !snapshot.ok || snapshot.stale) return
        let seen = {}
        try { seen = JSON.parse(config.notified) } catch (e) {}
        const next = {}
        for (const limit of snapshot.limits) {
            const previous = seen[limit.id]
            const before = previous && previous.reset === limit.resetsAt ? previous.level : 0
            const reached = level(limit)
            if (reached > before)
                notify(limit.label + " limit at " + limit.percent + "%",
                    [resetText(limit), forecast(limit)].filter(Boolean).join(" · "))
            next[limit.id] = { reset: limit.resetsAt, level: Math.max(reached, before) }
        }
        const text = JSON.stringify(next)
        if (text !== config.notified) config.notified = text
    }

    function openSettings() {
        expanded = false
        settings.active = true
        settings.item.show()
        settings.item.raise()
        settings.item.requestActivate()
    }

    // Burnbar has its own settings window, where every change applies at once, so Plasma's
    // Configure entry is pointed at it instead of the stock dialog with OK, Apply and Cancel.
    PlasmaCore.Action {
        id: settingsAction
        text: "Configure Burnbar…"
        icon.name: "configure"
        onTriggered: root.openSettings()
    }
    Component.onCompleted: Plasmoid.setInternalAction("configure", settingsAction)

    Loader {
        id: settings
        active: false
        sourceComponent: Window {
            title: "Burnbar Settings"
            flags: Qt.Dialog
            width: view.implicitWidth
            height: view.implicitHeight
            minimumWidth: view.implicitWidth
            minimumHeight: view.implicitHeight
            maximumWidth: view.implicitWidth
            maximumHeight: view.implicitHeight
            color: view.color

            Shortcut {
                sequences: [StandardKey.Cancel, StandardKey.Close]
                onActivated: close()
            }
            SettingsView {
                id: view
                anchors.fill: parent
                widget: root
            }
        }
    }

    Component {
        id: alert
        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: "burnbar"
            autoDelete: true
        }
    }

    P5Support.DataSource {
        engine: "executable"
        interval: root.interval * 1000
        connectedSources: [root.command + " --max-age " + (root.interval - 5)]
        onNewData: (source, data) => root.take(data)
    }
    P5Support.DataSource {
        id: shell
        property var pending: ({})
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            const done = pending[source]
            delete pending[source]
            if (done) done(data)
        }
    }
    // The command asks GitHub at most once a day; asking it every hour catches a wake from sleep.
    Timer {
        interval: 3600000
        running: root.config.checkUpdates
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkForUpdate(false)
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Plasmoid.icon: "burnbar"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Refresh"
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        }
    ]
    toolTipMainText: snapshot.ok ? "Claude " + snapshot.plan : "Burnbar"
    toolTipSubText: (snapshot.error ? problem() + (snapshot.hint ? "\n" + snapshot.hint : "") + "\n\n" : "")
        + (snapshot.loading ? "Loading…" : !snapshot.ok ? "" : toolTipLimits())
    function toolTipLimits() {
        return snapshot.limits.map(limit =>
            [limit.label + " " + limit.percent + "%", resetText(limit).toLowerCase(), forecast(limit)].filter(Boolean).join(" · ")).join("\n")
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth + 20
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.refresh()
            else root.expanded = !root.expanded
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 6
            color: Kirigami.Theme.textColor
            opacity: root.expanded ? 0.12 : parent.containsMouse ? 0.07 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12
            opacity: root.snapshot.stale ? 0.55 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Quiet {
                visible: root.panelLimits.length === 0
                text: root.snapshot.ok || root.snapshot.loading ? "CLAUDE" : "CLAUDE ?"
            }
            Repeater {
                model: root.panelLimits
                Reading {
                    required property var modelData
                    caption: root.caption(modelData)
                    value: root.shown(modelData)
                    style: root.config.style
                    tint: root.tint(modelData)
                    over: root.over(modelData)
                    ink: root.ink(modelData)
                    marker: root.elapsed(modelData)
                    countdown: root.config.showCountdown && modelData.resetsAt ? root.until(modelData.resetsAt) : ""
                }
            }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        component Note: RowLayout {
            property alias icon: glyph.source
            property alias text: words.text
            property alias color: words.color
            property real dim: 0.7

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                id: glyph
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                opacity: parent.dim
            }
            PlasmaComponents.Label {
                id: words
                Layout.fillWidth: true
                opacity: parent.dim
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }
        }

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    source: "burnbar"
                    fallback: "speedometer"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    spacing: 0
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 4
                        elide: Text.ElideRight
                        text: root.snapshot.plan ? "Claude " + root.snapshot.plan : "Claude"
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        opacity: 0.6
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideRight
                        text: root.refreshing ? "Refreshing…" : root.updated()
                    }
                }
                PlasmaComponents.ToolButton {
                    id: refreshButton
                    implicitWidth: implicitHeight
                    enabled: !root.refreshing
                    onClicked: root.refresh()
                    Accessible.name: "Refresh now"
                    PlasmaComponents.ToolTip { text: "Refresh now" }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.smallMedium
                        height: width
                        source: "view-refresh"
                        // Keeps turning until the data is in, and always ends on a full turn.
                        RotationAnimator on rotation {
                            running: root.refreshing
                            alwaysRunToEnd: true
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 700
                            easing.type: Easing.InOutCubic
                        }
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "configure"
                    onClicked: root.openSettings()
                    Accessible.name: "Settings"
                    PlasmaComponents.ToolTip { text: "Settings" }
                }
            }

            Note {
                visible: !!root.snapshot.error
                icon: "data-warning"
                color: root.warn
                dim: 1
                text: root.problem()

                // The hint says what the error means and what happens next.
                HoverHandler { id: problemHover }
                PlasmaComponents.ToolTip {
                    visible: problemHover.hovered && !!root.snapshot.hint
                    text: root.snapshot.hint || ""
                }
            }

            // Shown until the first answer arrives.
            RowLayout {
                visible: !!root.snapshot.loading
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.BusyIndicator {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    running: parent.visible
                }
                PlasmaComponents.Label {
                    opacity: 0.6
                    text: "Loading…"
                }
            }

            Repeater {
                model: root.snapshot.limits
                ColumnLayout {
                    id: entry
                    required property var modelData
                    readonly property color tint: root.tint(modelData)
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: entry.modelData.label
                        }
                        PlasmaComponents.Label {
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: root.level(entry.modelData) > 0 ? entry.tint : Kirigami.Theme.textColor
                            text: root.shown(entry.modelData) + "%" + (root.config.showRemaining ? " left" : "")
                        }
                    }
                    Bar {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        value: root.shown(entry.modelData)
                        tint: entry.tint
                        over: root.over(entry.modelData)
                        marker: root.elapsed(entry.modelData)
                    }
                    RowLayout {
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                            text: root.resetText(entry.modelData)
                        }
                        PlasmaComponents.Label {
                            opacity: root.ahead(entry.modelData) ? 1 : 0.6
                            color: root.ahead(entry.modelData) ? root.warn : Kirigami.Theme.textColor
                            font: Kirigami.Theme.smallFont
                            text: root.forecast(entry.modelData)
                        }
                    }
                    Graph {
                        Layout.fillWidth: true
                        visible: root.hasGraph(entry.modelData)
                        samples: entry.modelData.history
                        end: Date.parse(entry.modelData.resetsAt) / 1000
                        start: end - entry.modelData.windowHours * 3600
                        tint: root.ahead(entry.modelData) && root.level(entry.modelData) === 0 ? root.warn : entry.tint
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                visible: root.snapshot.breakdown.length > 0 || !!root.snapshot.extra || !!root.snapshot.reset
                    || root.restartPending || !!root.updateStatus.available
                opacity: 0.5
            }
            Note {
                visible: root.snapshot.breakdown.length > 0
                icon: "office-chart-pie"
                text: "This week: " + root.snapshot.breakdown.map(row => row.label + " " + row.percent + "%").join(" · ")
            }
            Note {
                visible: !!root.snapshot.extra
                icon: "wallet-open"
                text: root.snapshot.extra
                    ? "Extra usage: " + root.snapshot.extra.used + (root.snapshot.extra.limit === null ? "" : " of " + root.snapshot.extra.limit) + " " + root.snapshot.extra.currency
                    : ""
            }
            Note {
                visible: !!root.snapshot.reset
                icon: "edit-undo"
                text: root.resetOffer()
            }
            Note {
                visible: root.restartPending
                icon: "system-software-update"
                text: "Burnbar " + root.updateStatus.current + " is installed. Restart Plasma or log in again to load it."
            }
            Note {
                visible: !!root.updateStatus.available && !root.restartPending
                icon: "system-software-update"
                text: root.updating ? "Installing Burnbar " + root.updateStatus.latest + "…"
                    : root.updateStatus.error ? root.updateStatus.error
                    : "Burnbar " + root.updateStatus.latest + " is available."
                PlasmaComponents.Button {
                    visible: !root.updating
                    text: "Update"
                    onClicked: root.installUpdate()
                }
            }
        }
    }
}
