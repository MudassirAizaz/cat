pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components"

PanelFrame {
    id: root
    panelName: "session"
    centered: true
    panelWidth: 440
    panelHeight: 390
    property string error: ""
    onOpened: {
        error = "";
        focusEntry(0);
    }

    function focusEntry(index) {
        if (!entries.count) return;
        const wrapped = (index + entries.count) % entries.count;
        entries.itemAt(wrapped)?.forceActiveFocus(Qt.TabFocusReason);
    }

    function run(action) {
        if (runner.running)
            return;
        error = "";
        if (action === "lock") {
            Quickshell.execDetached(["hyprlock"]);
            ShellState.close();
            return;
        }
        runner.command = ["bash", Quickshell.shellPath("scripts/session.sh"), action];
        runner.running = true;
    }

    Process {
        id: runner
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.error = text.trim();
            }
        }
        onExited: (code, status) => {
            if (code === 0) {
                if (ShellState.panel === root.panelName)
                    ShellState.close();
            } else if (!root.error)
                root.error = "The action could not be completed.";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "POWER"
                font.pixelSize: Config.scaledFontSize(11)
                font.letterSpacing: 2
                Layout.fillWidth: true
            }
            CloseButton {
                panelTitle: "power menu"
            }
        }
        Repeater {
            id: entries
            model: [
                {
                    title: "Lock",
                    icon: "lock",
                    action: "lock"
                },
                {
                    title: "Suspend",
                    icon: "suspend",
                    action: "suspend"
                },
                {
                    title: "Hibernate",
                    icon: "hibernate",
                    action: "hibernate"
                },
                {
                    title: "Log out",
                    icon: "logout",
                    action: "logout"
                },
                {
                    title: "Restart",
                    icon: "restart",
                    action: "reboot"
                },
                {
                    title: "Shut down",
                    icon: "power",
                    action: "poweroff"
                }
            ]
            MenuEntry {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                title: modelData.title
                iconName: modelData.icon
                hasSubmenu: false
                destructive: modelData.action === "poweroff" || modelData.action === "reboot" || modelData.action === "logout"
                enabled: !runner.running
                onMoveRequested: delta => root.focusEntry(index + delta)
                onClicked: root.run(modelData.action)
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.error || (runner.running ? "Working…" : "")
            color: root.error ? Theme.danger : Theme.muted
            font.pixelSize: Config.scaledFontSize(10)
            wrapMode: Text.Wrap
        }
    }
}
