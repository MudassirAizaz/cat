pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Scope {
    id: root
    property var entries: []
    property string error: ""
    property string operation: ""
    readonly property bool busy: reader.running || worker.running
    readonly property string helper: Quickshell.shellPath("scripts/clipboard.sh")

    function refresh() {
        if (!busy) reader.running = true;
    }

    function run(action, id) {
        if (busy) return;
        error = "";
        operation = action;
        worker.command = ["bash", helper, action, String(id || "")];
        worker.running = true;
    }

    Process {
        id: reader
        command: ["bash", root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = text.split("\n").filter(line => /^\d+\t/.test(line)).map(line => {
                    const [id, preview, imagePath = ""] = line.split("\t");
                    return { id, preview, imagePath };
                });
                if (JSON.stringify(next) !== JSON.stringify(root.entries)) root.entries = next;
            }
        }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) root.error = text.trim(); } }
        onExited: (code, status) => { if (code === 0) root.error = ""; }
    }

    Process {
        id: worker
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) root.error = text.trim(); } }
        onExited: (code, status) => {
            if (code === 0 && root.operation === "copy") ShellState.close();
            if (code !== 0 && !root.error) root.error = "Clipboard operation failed. Check cliphist and wl-clipboard.";
            if (code === 0) Qt.callLater(root.refresh);
        }
    }

    Timer {
        interval: 2000
        running: ShellState.panel === "clipboard"
        repeat: true
        onTriggered: root.refresh()
    }
}
