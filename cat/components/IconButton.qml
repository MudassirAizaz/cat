import QtQuick
import ".."

ActionButton {
    id: root
    property string iconName: "apps"
    property color iconColor: selected ? Theme.onAccent : Theme.foreground
    property real level: 1
    implicitWidth: 30
    implicitHeight: 28
    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: root.iconName
            color: root.iconColor
            level: root.level
            opacity: root.enabled ? 1 : 0.4
        }
    }
}
