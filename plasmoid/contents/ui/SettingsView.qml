pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The whole settings window: one tab per topic.
// There is nothing to confirm: every control writes its change to the widget at once.
Rectangle {
    id: view

    required property var widget          // the PlasmoidItem, for its configuration, colours and updates
    property int tab: 0

    readonly property var tabs: [
        { name: "Appearance", icon: "preferences-desktop-theme-global" },
        { name: "Warnings", icon: "preferences-desktop-notification-bell" },
        { name: "Data", icon: "preferences-system-network" },
        { name: "About", icon: "help-about" }
    ]

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor
    implicitWidth: Kirigami.Units.gridUnit * 32
    implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2

    ColumnLayout {
        id: column
        // Not filled: the window takes its height from this column, not the other way round.
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // Tab switcher: one rounded track with a pill that slides under the chosen tab.
        Item {
            Layout.fillWidth: true
            implicitHeight: track.height

            Rectangle {
                id: track
                anchors.centerIn: parent
                width: segments.width + 8
                height: segments.height + 8
                radius: height / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

                Rectangle {
                    id: pill
                    readonly property Item target: segments.children[view.tab] || null
                    x: segments.x + (target ? target.x : 0)
                    y: segments.y
                    width: target ? target.width : 0
                    height: segments.height
                    radius: height / 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.13)
                    border.width: 1
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: segments
                    anchors.centerIn: parent

                    Repeater {
                        model: view.tabs

                        MouseArea {
                            id: segment
                            required property var modelData
                            required property int index
                            readonly property bool current: view.tab === index
                            width: label.implicitWidth + Kirigami.Units.largeSpacing * 3
                            height: label.implicitHeight + Kirigami.Units.smallSpacing * 3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.tab = index

                            Row {
                                id: label
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing * 2
                                opacity: segment.current ? 1 : segment.containsMouse ? 0.85 : 0.6
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Kirigami.Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: segment.modelData.icon
                                    width: Kirigami.Units.iconSizes.small
                                    height: width
                                }
                                QQC2.Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: segment.modelData.name
                                    font.weight: segment.current ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }
        }
        StackLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            // A hidden page reports no height, so the tallest one seen so far is remembered:
            // the window opens on the tallest page and then keeps its size from tab to tab.
            property real tallest: 0
            readonly property real current: Math.max(appearance.implicitHeight, warnings.implicitHeight,
                dataPage.implicitHeight, about.implicitHeight)
            onCurrentChanged: tallest = Math.max(tallest, current)
            Layout.preferredHeight: Math.max(tallest, current)
            currentIndex: view.tab

            Item {
                implicitHeight: appearance.implicitHeight
                PageAppearance { id: appearance; width: parent.width; config: view.widget.config }
            }
            Item {
                implicitHeight: warnings.implicitHeight
                PageWarnings { id: warnings; width: parent.width; widget: view.widget }
            }
            Item {
                implicitHeight: dataPage.implicitHeight
                PageData { id: dataPage; width: parent.width; config: view.widget.config }
            }
            Item {
                implicitHeight: about.implicitHeight
                PageAbout { id: about; width: parent.width; widget: view.widget }
            }
        }
    }
}
