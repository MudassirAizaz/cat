"""Protect asynchronous service state and notification lifetime rules."""
from pathlib import Path
import shutil
import tempfile
import unittest

from support import ROOT, assert_qml_passes, qml_environment


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "services").mkdir()
        (self.root / "scripts").mkdir()
        (self.root / "ShellState.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property string panel: ""
    function close() { panel = ""; }
}
''')
        shutil.copy(ROOT / "Config.qml", self.root / "Config.qml")
        (self.root / "qmldir").write_text(
            "singleton ShellState 1.0 ShellState.qml\nsingleton Config 1.0 Config.qml\n"
        )
        self.env = qml_environment(self.root)

    def stage_service(self, name):
        shutil.copy(ROOT / "services" / f"{name}.qml", self.root / "services")
        (self.root / "services/qmldir").write_text(f"singleton {name} 1.0 {name}.qml\n")

    def run_qml(self, body, marker):
        (self.root / "shell.qml").write_text(body)
        assert_qml_passes(self, self.root, marker, self.env)

    def test_clipboard_completion_preserves_another_panel_and_failed_refresh_preserves_entries(self):
        self.stage_service("Clipboard")
        self.env["CAT_TEST_FAILURE"] = str(self.root / "fail-list")
        (self.root / "scripts/clipboard.sh").write_text('''case "$1" in
    list)
        if [ -f "$CAT_TEST_FAILURE" ]; then echo "Listing failed" >&2; exit 1; fi
        printf '1\tKeep this entry\t\n'
        ;;
    copy) sleep 0.1; : > "$CAT_TEST_FAILURE" ;;
esac
''')
        self.run_qml('''import QtQuick
import Quickshell
import "services"
ShellRoot {
    property bool copied: false
    Connections { target: Clipboard; function onCopied() { copied = true; } }
    Component.onCompleted: Clipboard.refresh()
    Timer {
        property int step: 0
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (Clipboard.busy) return;
            try {
                if (step === 0) {
                    if (Clipboard.entries.length !== 1) throw new Error("initial list");
                    Clipboard.run("copy", "1");
                    ShellState.panel = "network";
                    step++;
                } else {
                    if (!copied || ShellState.panel !== "network") throw new Error("copy changed another panel");
                    if (Clipboard.error !== "Listing failed") throw new Error("failure is reported");
                    if (Clipboard.entries.length !== 1) throw new Error("failure erased entries");
                    console.log("CLIPBOARD_LIFECYCLE_PASS");
                    Qt.quit();
                }
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''', "CLIPBOARD_LIFECYCLE_PASS")

    def test_notification_history_expiration_and_hidden_sticky_transients(self):
        self.stage_service("Notifications")
        fake = self.root / "fake"
        fake.mkdir()
        (fake / "qmldir").write_text(
            "singleton Backend 1.0 Backend.qml\n"
            "singleton NotificationUrgency 1.0 NotificationUrgency.qml\n"
            "NotificationServer 1.0 NotificationServer.qml\n"
        )
        (fake / "Backend.qml").write_text('''pragma Singleton
import QtQuick
QtObject { property var notifications: [] }
''')
        (fake / "NotificationUrgency.qml").write_text('''pragma Singleton
import QtQuick
QtObject { enum Value { Low, Normal, Critical } }
''')
        (fake / "NotificationServer.qml").write_text('''import QtQuick
QtObject {
    property bool keepOnReload: false
    property bool persistenceSupported: false
    property bool bodySupported: false
    property bool actionsSupported: false
    property var trackedNotifications: ({ values: Backend.notifications })
    signal notification(var notification)
}
''')
        path = self.root / "services/Notifications.qml"
        path.write_text(path.read_text().replace(
            "import Quickshell.Services.Notifications", 'import "../fake"'
        ))
        self.run_qml('''import QtQuick
import Quickshell
import "services"
import "fake"
ShellRoot {
    id: root
    property var expired: []
    function check(value, message) { if (!value) throw new Error(message); }
    function note(id, transient, sticky) {
        const callbacks = [];
        const close = () => {
            Backend.notifications = Backend.notifications.filter(n => n.id !== id);
            callbacks.forEach(callback => callback());
        };
        const notification = {
            id, transient, expireTimeout: sticky ? 0 : -1,
            urgency: NotificationUrgency.Normal, tracked: false, lastGeneration: false,
            closed: { connect: callback => callbacks.push(callback) },
            expire: () => { root.expired = root.expired.concat([id]); close(); },
            dismiss: close
        };
        Backend.notifications = Backend.notifications.concat([notification]);
        Notifications.receive(notification);
    }
    Component.onCompleted: {
        try {
            note(1, false, false);
            check(Notifications.history.length === 1 && Notifications.unread === 1, "ordinary history");
            Notifications.expireDue(Date.now() + Config.toastDuration + 1);
            check(Notifications.popups.length === 0 && Notifications.history.length === 1, "popup expiration retains history");
            Notifications.markRead();
            check(Notifications.unread === 0, "mark read");
            note(2, true, false);
            Notifications.expireDue(Date.now() + Config.toastDuration + 1);
            check(expired.includes(2) && !Notifications.metadata[2], "transient released");
            note(3, true, true);
            Notifications.doNotDisturb = true;
            check(expired.includes(3) && !Notifications.metadata[3], "DND releases sticky transient");
            note(4, true, true);
            check(Notifications.metadata[4].deadline > 0, "suppressed sticky transient gets deadline");
            Notifications.expireDue(Date.now() + Config.toastDuration + 1);
            check(expired.includes(4), "suppressed transient expires");
            Notifications.doNotDisturb = false;
            note(5, true, true);
            Notifications.markRead();
            check(expired.includes(5), "history view releases sticky transient");
            Notifications.clear();
            check(Notifications.history.length === 0 && Object.keys(Notifications.metadata).length === 0, "clear releases metadata");
            Config.notificationLimit = 1;
            note(6, false, false);
            note(7, false, false);
            Qt.callLater(() => {
                try {
                    check(Notifications.history.length === 1 && Notifications.history[0].id === 7, "history limit retains newest");
                    console.log("NOTIFICATIONS_LIFECYCLE_PASS");
                } catch (error) { console.log("TEST FAILURE", error.message); }
                Qt.quit();
            });
        } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
    }
}
''', "NOTIFICATIONS_LIFECYCLE_PASS")

    def test_wallpaper_selection_and_failed_refresh_preserve_previous_state(self):
        self.stage_service("WallpaperState")
        (self.root / "Theme.qml").write_text(
            'pragma Singleton\nimport QtQuick\nQtObject { property string wallpaper: "" }\n'
        )
        with (self.root / "qmldir").open("a") as definitions:
            definitions.write("singleton Theme 1.0 Theme.qml\n")
        (self.root / "scripts/wallpapers.py").write_text('''import json
from pathlib import Path
import sys
state = Path(__file__).with_suffix(".state")
if sys.argv[1] == "list":
    if state.exists():
        print("invalid JSON")
    else:
        print(json.dumps([{"name": "Image", "path": "/image with spaces.png"}]))
else:
    state.write_text(sys.argv[2])
''')
        self.run_qml('''import QtQuick
import Quickshell
import "services"
ShellRoot {
    Component.onCompleted: WallpaperState.refresh()
    Timer {
        property int step: 0
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (WallpaperState.busy) return;
            try {
                if (step === 0) {
                    if (WallpaperState.wallpapers.length !== 1) throw new Error("initial list");
                    WallpaperState.set("/image with spaces.png");
                    step++;
                } else if (step === 1) {
                    if (WallpaperState.currentPath !== "/image with spaces.png" || WallpaperState.pendingPath)
                        throw new Error("selection saved after successful apply");
                    WallpaperState.refresh();
                    step++;
                } else {
                    if (!WallpaperState.error || WallpaperState.wallpapers.length !== 1)
                        throw new Error("malformed result erased previous list");
                    if (WallpaperState.currentPath !== "/image with spaces.png")
                        throw new Error("failed listing changed selection");
                    console.log("WALLPAPER_LIFECYCLE_PASS");
                    Qt.quit();
                }
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''', "WALLPAPER_LIFECYCLE_PASS")


if __name__ == "__main__":
    unittest.main()
