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
        if (busy) return;
        error = "";
        listing.running = true;
    }

    function set(path) {
        if (busy || !wallpapers.some(wallpaper => wallpaper.path === path)) return;
        error = "";
        pendingPath = path;
        applying.command = ["python3", helper, "set", path];
        applying.running = true;
    }

    Process {
        id: listing
        command: ["python3", root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.wallpapers = JSON.parse(text); }
                catch (error) { root.wallpapers = []; root.error = "Could not read the wallpaper folder."; }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) root.error = text.trim(); }
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.error) root.error = "Could not read the wallpaper folder.";
        }
    }

    Process {
        id: applying
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) root.error = text.trim(); }
        }
        onExited: (code, status) => {
            if (code === 0) Theme.wallpaper = root.pendingPath;
            else if (!root.error) root.error = "Could not set the wallpaper. Check hyprpaper is running with IPC enabled.";
            root.pendingPath = "";
        }
    }
}
