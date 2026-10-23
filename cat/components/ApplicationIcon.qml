import QtQuick
import Quickshell
import ".."

Item {
    id: root
    property string iconName: ""
    property color fallbackColor: Theme.foreground
    implicitWidth: 18
    implicitHeight: 18

    Image {
        id: image
        anchors.fill: parent
        source: root.iconName ? Quickshell.iconPath(root.iconName, true) : ""
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
    Icon {
        anchors.fill: parent
        name: "apps"
        color: root.fallbackColor
        visible: image.status !== Image.Ready
    }
}
