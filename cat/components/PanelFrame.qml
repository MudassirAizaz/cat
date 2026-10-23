import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root
    property string panelName: ""
    property bool centered: false
    property int panelWidth: 420
    property int panelHeight: 540
    default property alias panelContent: body.data
    readonly property alias panelBody: body
    signal opened

    screen: ShellState.panelScreen || ShellState.focusedScreen
    visible: ShellState.panel === panelName
    implicitWidth: screen?.width || 800
    implicitHeight: (screen?.height || 800) - Config.barHeight
    color: Theme.clear
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    // The transparent surface catches outside taps without covering the bar.
    margins.top: Config.barHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cat-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    // Hyprland also redirects pointer input to exclusive layers, blocking the bar.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => {
                if (!root.visible)
                    return;
                body.forceActiveFocus();
                root.opened();
            });
    }

    data: [
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: event => {
                // Empty space within the panel is still part of the panel.
                if (event.x < body.x || event.x >= body.x + body.width || event.y < body.y || event.y >= body.y + body.height)
                    ShellState.close();
            }
        },
        Rectangle {
            id: body
            width: Math.min(root.panelWidth, parent.width - Config.gap * 2)
            height: Math.max(0, Math.min(root.panelHeight, parent.height - y - Config.gap))
            x: {
                if (root.centered)
                    return Math.round((parent.width - width) / 2);
                const rightEdge = parent.width - width - Config.gap;
                if (ShellState.panelAnchorX < 0)
                    return rightEdge;
                const anchored = Math.round(ShellState.panelAnchorX - width / 2);
                return Math.max(Config.gap, Math.min(rightEdge, anchored));
            }
            y: root.centered ? Math.max(Config.gap, Math.round((root.screen?.height || 800) * 0.18) - Config.barHeight) : Config.gap
            color: Theme.surface
            border.color: Theme.border
            radius: Config.radius + 2
            focus: true
            Keys.onEscapePressed: ShellState.close()
            Keys.onPressed: event => ShellState.handleNavigationKey(event)
            Keys.onLeftPressed: ShellState.back()
            Keys.onRightPressed: ShellState.forward()
        }
    ]
}
