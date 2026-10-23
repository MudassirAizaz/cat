pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    property bool active: false
    property bool ready: false
    property string token: ""
    property bool pending: false
    readonly property string key: "cat-window-" + Quickshell.processId
    signal pressed(real x, real y)

    onActiveChanged: {
        ready = false;
        if (active)
            token = key + "-" + Date.now();
        sync();
    }

    function command(enabled) {
        return ["hyprctl", "eval", "local key = " + JSON.stringify(key)
            + "\nlocal token = " + JSON.stringify(token)
            + "\nlocal enabled = " + (enabled ? "true" : "false")
            + "\n" + script.text()];
    }

    function sync() {
        if (!Hyprland.usingLua)
            return;
        if (writer.running) {
            pending = true;
            return;
        }
        pending = false;
        writer.installing = active;
        writer.token = token;
        writer.command = command(active);
        writer.running = true;
    }

    Component.onDestruction: {
        if (Hyprland.usingLua && token)
            Quickshell.execDetached(command(false));
    }

    FileView {
        id: script
        path: Quickshell.shellPath("scripts/window-input.lua")
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            reload();
            if (root.active)
                root.sync();
        }
    }
    Process {
        id: writer
        property bool installing: false
        property string token: ""
        onExited: (code, status) => {
            root.ready = code === 0 && installing && root.active && token === root.token;
            if (code !== 0)
                console.warn("Window input listener unavailable; using outside-click overlay");
            if (root.pending)
                Qt.callLater(root.sync);
        }
    }
    Connections {
        target: Hyprland
        function onUsingLuaChanged() { root.sync(); }
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.ready = false;
                if (root.active)
                    root.sync();
                return;
            }
            if (!root.active || !root.ready || event.name !== "custom")
                return;
            const parts = event.data.split(",");
            if (parts.length !== 3 || parts[0] !== root.token)
                return;
            const x = Number(parts[1]);
            const y = Number(parts[2]);
            if (Number.isFinite(x) && Number.isFinite(y))
                root.pressed(x, y);
        }
    }
}
