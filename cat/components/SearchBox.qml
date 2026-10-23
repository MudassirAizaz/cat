import QtQuick
import QtQuick.Controls
import ".."

TextField {
    id: root
    implicitHeight: 46
    leftPadding: 15
    rightPadding: 15
    color: Theme.foreground
    placeholderTextColor: Theme.subtle
    selectionColor: Theme.accent
    selectedTextColor: Theme.onAccent
    font.family: Config.fontFamily
    font.pixelSize: Config.fontSize
    selectByMouse: true
    Keys.onPressed: event => {
        if (root.text.length === 0)
            ShellState.handleNavigationKey(event);
    }
    background: Rectangle {
        color: Theme.background
        radius: Config.radius
        border.color: root.activeFocus ? Theme.accent : Theme.border
    }
}
