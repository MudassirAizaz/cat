import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// The panel itself handles its screen; this covers the other monitors.
PanelWindow {
    required property var modelData
    screen: modelData
    visible: ShellState.panel !== ""
        && screen !== (ShellState.panelScreen || ShellState.focusedScreen)
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.top: Config.barHeight
    color: Theme.clear
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cat-outside-dismiss"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: ShellState.close()
    }
}
