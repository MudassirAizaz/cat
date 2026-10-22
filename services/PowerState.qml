pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Scope {
    id: root
    property var profiles: []
    property string active: ""
    property string error: ""
    property bool loaded: false
    readonly property bool busy: reader.running || writer.running

    function refresh() {
        if (!busy) reader.running = true;
    }

    function select(profile) {
        if (busy || profiles.indexOf(profile) === -1) return;
        error = "";
        writer.command = ["powerprofilesctl", "set", profile];
        writer.running = true;
    }

    function title(profile) {
        return ({ "power-saver": "Power saver", balanced: "Balanced", performance: "Performance" })[profile] || profile;
    }

    Process {
        id: reader
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const profiles = [];
                let current = "";
                text.split("\n").forEach(line => {
                    const match = line.match(/^\s*(\*)?\s*(power-saver|balanced|performance):\s*$/);
                    if (!match) return;
                    profiles.push(match[2]);
                    if (match[1]) current = match[2];
                });
                root.profiles = profiles;
                root.active = current;
            }
        }
        onExited: (code, status) => {
            root.loaded = true;
            root.error = code === 0 ? "" : "Power profiles are unavailable. Check that power-profiles-daemon is installed and running.";
        }
    }

    Process {
        id: writer
        onExited: (code, status) => {
            if (code === 0) Qt.callLater(root.refresh);
            else root.error = "Could not change profile. Check your power service and permissions.";
        }
    }

    Timer {
        interval: 8000
        running: ShellState.panel === "power"
        repeat: true
        onTriggered: root.refresh()
    }
}
