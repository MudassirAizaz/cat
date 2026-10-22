pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

PanelWindow {
    id: root
    screen: ShellState.focusedScreen
    visible: Notifications.popups.length > 0 && ShellState.panel === "" && !Notifications.doNotDisturb
    anchors.top: true
    anchors.right: true
    margins.top: Config.barHeight + Config.gap
    margins.right: Config.gap
    implicitWidth: Math.min(380, (screen?.width || 400) - Config.gap * 2)
    implicitHeight: Math.min(stack.implicitHeight, (screen?.height || 800) - Config.barHeight - Config.gap * 2)
    color: Theme.clear
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cat-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Flickable {
        anchors.fill: parent
        contentHeight: stack.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: stack
            width: parent.width
            spacing: 8
            Repeater {
                model: Notifications.popups
                NotificationCard { required property var modelData; width: stack.width; notification: modelData }
            }
        }
    }
}
