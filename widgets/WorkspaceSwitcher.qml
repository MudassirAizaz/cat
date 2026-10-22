pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quickshell.Hyprland
import ".."
import "../components"

Item {
    id: root
    property var monitor: null
    readonly property var workspaceIds: {
        const ids = Array.from({ length: Config.workspaceCount }, (_, i) => i + 1);
        Hyprland.workspaces.values.forEach(w => { if (w.id > 0 && !ids.includes(w.id)) ids.push(w.id); });
        return ids.sort((a, b) => a - b);
    }
    implicitWidth: slots.implicitWidth
    implicitHeight: 28

    Row {
        id: slots
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: root.workspaceIds
            T.Button {
                id: button
                required property int modelData
                readonly property bool active: root.monitor?.activeWorkspace?.id === modelData
                width: 24
                height: 28
                padding: 0
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                Accessible.name: "Workspace " + modelData
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                background: Rectangle {
                    radius: 3
                    color: button.hovered ? Theme.raised : Theme.clear
                }
                contentItem: Item {
                    Rectangle {
                        anchors.centerIn: parent
                        width: 9
                        height: 9
                        radius: 2
                        visible: button.active
                        color: Theme.accent
                    }
                    Label {
                        anchors.fill: parent
                        visible: !button.active
                        text: button.modelData
                        color: Theme.accent
                        font.pixelSize: Config.scaledFontSize(12)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                onClicked: {
                    ShellState.close();
                    Hyprland.dispatch(Hyprland.usingLua
                        ? "hl.dsp.focus({ workspace = " + modelData + " })"
                        : "workspace " + modelData);
                }
            }
        }
    }
}
