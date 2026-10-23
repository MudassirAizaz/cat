pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Scope {
    id: root
    property var wallpapers: []
    property string error: ""
    property string pendingPath: ""
    readonly property string helper: Quickshell.shellPath("scripts/wallpapers.py")
    readonly property bool busy: listing.running || applying.running
    readonly property string currentPath: Theme.wallpaper

    function refresh() {
        if (busy)
            return;
        error = "";
        listing.running = true;
    }

    function set(path) {
        if (busy || !wallpapers.some(wallpaper => wallpaper.path === path))
            return;
        error = "";
        pendingPath = path;
        applying.command = ["python3", helper, "set", path];
        applying.running = true;
    }

    Process {
        id: listing
        command: ["python3", root.helper, "list"]
        stdout: StdioCollector {
            id: listOutput
        }
        stderr: StdioCollector {
            id: listError
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.error = listError.text.trim() || "Could not read the wallpaper folder.";
                return;
            }
            try {
                const wallpapers = JSON.parse(listOutput.text);
                if (!Array.isArray(wallpapers))
                    throw new Error("Expected a wallpaper list.");
                root.wallpapers = wallpapers;
                root.error = "";
            } catch (error) {
                root.error = "Could not read the wallpaper folder.";
            }
        }
    }

    Process {
        id: applying
        stderr: StdioCollector {
            id: applyError
        }
        onExited: (code, status) => {
            if (code === 0)
                Theme.wallpaper = root.pendingPath;
            else
                root.error = applyError.text.trim() || "Could not set the wallpaper. Check hyprpaper is running with IPC enabled.";
            root.pendingPath = "";
        }
    }
}
