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
    signal copied

    function parseEntries(text) {
        return text.split("\n").filter(line => /^\d+\t/.test(line)).map(line => {
            const [id, preview, imagePath = ""] = line.split("\t");
            return {
                id,
                preview,
                imagePath
            };
        });
    }

    function refresh() {
        if (!busy)
            reader.running = true;
    }

    function run(action, id) {
        if (busy)
            return;
        error = "";
        operation = action;
        worker.command = ["bash", helper, action, String(id || "")];
        worker.running = true;
    }

    Process {
        id: reader
        command: ["bash", root.helper, "list"]
        stdout: StdioCollector {
            id: listOutput
        }
        stderr: StdioCollector {
            id: listError
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.error = listError.text.trim() || "Could not read clipboard history. Check cliphist is installed.";
                return;
            }
            const next = root.parseEntries(listOutput.text);
            if (JSON.stringify(next) !== JSON.stringify(root.entries))
                root.entries = next;
            root.error = "";
        }
    }

    Process {
        id: worker
        stderr: StdioCollector {
            id: workerError
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.error = workerError.text.trim() || "Clipboard operation failed. Check cliphist and wl-clipboard.";
                return;
            }
            if (root.operation === "copy")
                root.copied();
            Qt.callLater(root.refresh);
        }
    }

    Timer {
        interval: 2000
        running: ShellState.panel === "clipboard"
        repeat: true
        onTriggered: root.refresh()
    }
}
