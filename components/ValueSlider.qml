import QtQuick
import QtQuick.Templates as T
import ".."

T.Slider {
    id: root
    implicitWidth: 220
    implicitHeight: 28
    from: 0
    to: 1
    stepSize: 0.01
    leftPadding: 7
    rightPadding: 7
    focusPolicy: Qt.StrongFocus
    background: Rectangle {
        x: root.leftPadding
        y: Math.round((root.height - height) / 2)
        width: root.availableWidth
        height: 4
        radius: 2
        color: Theme.border
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: Math.round((root.height - height) / 2)
        width: 14
        height: 14
        radius: 7
        color: Theme.accent
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.foreground
    }
}
