pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

PanelFrame {
    id: root
    panelName: "notifications"
    panelWidth: 420
    panelHeight: 600
    onOpened: Notifications.markRead()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16
        RowLayout {
            Label { text: "NOTIFICATIONS"; font.pixelSize: Config.scaledFontSize(11); font.letterSpacing: 2; Layout.fillWidth: true }
            ActionButton { text: "clear"; enabled: Notifications.history.length > 0; onClicked: Notifications.clear() }
            CloseButton { panelTitle: "notifications" }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            color: Theme.raised
            radius: Config.radius
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                Label { text: "Do not disturb"; Layout.fillWidth: true; font.pixelSize: Config.scaledFontSize(12) }
                ActionButton { text: Notifications.doNotDisturb ? "on" : "off"; selected: Notifications.doNotDisturb; hint: "Toggle notification popups"; onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb }
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 10
                model: Notifications.history
                boundsBehavior: Flickable.StopAtBounds
                delegate: NotificationCard {
                    required property var modelData
                    width: list.width
                    notification: modelData
                }
            }
            EmptyState { anchors.centerIn: parent; width: parent.width - 30; visible: list.count === 0; title: "All quiet here"; subtitle: "You're all caught up." }
        }
        Label { text: Notifications.history.length + " notifications  ·  " + (Notifications.doNotDisturb ? "popups paused" : "up to date"); color: Theme.subtle; font.pixelSize: Config.scaledFontSize(10) }
    }
}
