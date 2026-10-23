pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import ".."
import "../services"

Rectangle {
    id: root
    required property var notification
    implicitHeight: content.implicitHeight + 28
    color: Theme.background
    border.color: notification?.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.border
    radius: Config.radius

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 8
        RowLayout {
            Label {
                text: root.notification?.appName || "Notification"
                color: Theme.accent
                font.pixelSize: Config.scaledFontSize(10)
                font.letterSpacing: 1
                Layout.fillWidth: true
            }
            Label {
                text: root.notification ? Notifications.timeFor(root.notification.id) : ""
                color: Theme.subtle
                font.pixelSize: Config.scaledFontSize(10)
            }
            IconButton {
                iconName: "close"
                hint: "Dismiss notification"
                implicitWidth: 26
                implicitHeight: 24
                onClicked: root.notification?.dismiss()
            }
        }
        Label {
            text: root.notification?.summary || ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            maximumLineCount: 3
            font.bold: true
        }
        Label {
            text: root.notification?.body || ""
            visible: text.length > 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            maximumLineCount: 6
            color: Theme.muted
            font.pixelSize: Config.scaledFontSize(12)
        }
        Flow {
            Layout.fillWidth: true
            spacing: 5
            visible: (root.notification?.actions.length || 0) > 0
            Repeater {
                model: root.notification?.actions || []
                ActionButton {
                    required property var modelData
                    text: modelData.text || "Open"
                    implicitWidth: Math.min(implicitContentWidth + 20, content.width)
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
