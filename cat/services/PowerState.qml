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
    readonly property var profileNames: ({
            "power-saver": "Power saver",
            balanced: "Balanced",
            performance: "Performance"
        })

    function refresh() {
        if (!busy)
            reader.running = true;
    }

    function select(profile) {
        if (busy || profiles.indexOf(profile) === -1)
            return;
        error = "";
        writer.command = ["powerprofilesctl", "set", profile];
        writer.running = true;
    }

    function title(profile) {
        return profileNames[profile] || profile;
    }

    function parseProfiles(text) {
        const profiles = [];
        let active = "";
        text.split("\n").forEach(line => {
            const match = line.match(/^\s*(\*)?\s*([\w-]+):\s*$/);
            if (!match || !Object.keys(profileNames).includes(match[2]))
                return;
            profiles.push(match[2]);
            if (match[1])
                active = match[2];
        });
        return {
            profiles,
            active
        };
    }

    Process {
        id: reader
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            id: listOutput
        }
        onExited: (code, status) => {
            root.loaded = true;
            if (code !== 0) {
                root.error = "Power profiles are unavailable. Check that power-profiles-daemon is installed and running.";
                return;
            }
            const parsed = root.parseProfiles(listOutput.text);
            root.profiles = parsed.profiles;
            root.active = parsed.active;
            root.error = "";
        }
    }

    Process {
        id: writer
        onExited: (code, status) => {
            if (code === 0)
                Qt.callLater(root.refresh);
            else
                root.error = "Could not change profile. Check your power service and permissions.";
        }
    }

    Timer {
        interval: 8000
        running: ShellState.panel === "power"
        repeat: true
        onTriggered: root.refresh()
    }
}
