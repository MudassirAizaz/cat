"""Exercise application identity and the window-details popup with fake windows."""
from pathlib import Path
import shutil
import tempfile
import unittest

from support import ROOT, assert_qml_passes, floating_window


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class WindowTests(unittest.TestCase):
    def test_app_identity_live_focus_details_and_closed_windows(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ("components", "services", "widgets"):
                shutil.copytree(ROOT / folder, root / folder)
            (root / "panels").mkdir()
            shutil.copy(ROOT / "panels/WindowPanel.qml", root / "panels")
            for name in ("Config.qml", "Theme.qml", "ShellState.qml", "qmldir"):
                shutil.copy(ROOT / name, root / name)
            for name in ("components/PanelFrame.qml", "widgets/Bar.qml"):
                path = root / name
                path.write_text(floating_window(path.read_text()))

            fake = root / "fake"
            fake.mkdir()
            (fake / "qmldir").write_text(
                "singleton Hyprland 1.0 Hyprland.qml\n"
                "singleton DesktopEntries 1.0 DesktopEntries.qml\n"
            )
            (fake / "Hyprland.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var activeToplevel: null
    property var toplevels: ({values: []})
    property int refreshes: 0
    function refreshToplevels() { refreshes++; }
}
''')
            (fake / "DesktopEntries.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    function heuristicLookup(id) {
        return id === "com.test.Terminal"
            ? {name: "Test Terminal", icon: "utilities-terminal"} : null;
    }
}
''')
            path = root / "services/WindowState.qml"
            path.write_text(path.read_text().replace(
                "import Quickshell\n", 'import "../fake"\n'
            ).replace("import Quickshell.Hyprland\n", ""))
            (root / "shell.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import "panels"
import "widgets"
import "services"
import "fake"
ShellRoot {
    id: root
    Bar { id: bar; modelData: Quickshell.screens[0]; implicitWidth: 1400 }
    WindowPanel { id: popup }
    TestEvent { id: events }
    property QtObject terminal: QtObject {
        property string title: "A long document title — Test Terminal"
        property bool urgent: false
        property QtObject wayland: QtObject {
            property string appId: "com.test.Terminal"
            property bool fullscreen: false
            property bool maximized: false
        }
        property var monitor: ({name: "DP-1"})
        property var workspace: ({name: "3", toplevels: {values: [root.terminal]}})
        property var lastIpcObject: ({
            class: "com.test.Terminal", initialClass: "com.test.Terminal", pid: 1234,
            floating: false, pinned: false, fullscreen: 0, at: [-10, 42],
            size: [1280, 720], xwayland: false
        })
    }
    property QtObject unknown: QtObject {
        property string title: "Unregistered application"
        property bool urgent: true
        property var wayland: null
        property var workspace: null
        property var monitor: null
        property var lastIpcObject: ({class: "unregistered-app", floating: true, pinned: true})
    }
    Component.onCompleted: {
        Hyprland.toplevels = {values: [terminal, unknown]};
        Hyprland.activeToplevel = terminal;
    }
    Timer {
        property int step: 0
        interval: 120
        repeat: true
        running: true
        function check(value, message) { if (!value) throw new Error(message); }
        function find(item, name) {
            if (item.objectName === name) return item;
            for (const child of item.children || []) {
                const found = find(child, name);
                if (found) return found;
            }
            return null;
        }
        function click(item) {
            events.mouseClick(item, item.width / 2, item.height / 2,
                Qt.LeftButton, Qt.NoModifier, 0);
        }
        onTriggered: {
            try {
                const button = find(bar.contentItem, "windowButton");
                if (step === 0) {
                    check(button.visible && button.enabled, "application button is available");
                    check(button.text === "Test Terminal", "bar uses app name rather than window title");
                    check(find(bar.contentItem, "windowButtonIcon").iconName === "utilities-terminal", "app icon resolved");
                    click(button);
                    Hyprland.activeToplevel = null;
                } else if (step === 1) {
                    check(popup.visible && popup.targetWindow === root.terminal, "capture survives panel taking focus");
                    check(Hyprland.refreshes > 0, "opening requests fresh metadata");
                    check(find(popup.contentItem, "windowApplication").text === "Test Terminal", "popup app name");
                    check(find(popup.contentItem, "windowTitle").text === root.terminal.title, "full title in popup");
                    const details = {};
                    popup.details.forEach(row => details[row.label] = row.value);
                    check(Object.keys(details).length === 3, "popup contains only the retained details");
                    check(details["Application ID"] === "com.test.Terminal", "application ID");
                    check(details["Size"] === "1280 × 720", "window size");
                    check(details["Process ID"] === "1234", "process ID");
                    Hyprland.activeToplevel = root.unknown;
                } else if (step === 2) {
                    check(popup.visible && popup.targetWindow === root.unknown, "focus changes update the open panel without reopening");
                    check(find(popup.contentItem, "windowApplication").text === "unregistered-app", "popup application follows focus");
                    check(find(popup.contentItem, "windowTitle").text === root.unknown.title, "popup title follows focus");
                    check(button.text === "unregistered-app", "unknown app falls back to class");
                    check(find(bar.contentItem, "windowButtonIcon").iconName === "", "unknown app uses generic icon");
                    root.unknown.title = "Updated title";
                    root.unknown.lastIpcObject = {class: "unregistered-app", size: [900, 600], pid: 5678};
                } else if (step === 3) {
                    check(find(popup.contentItem, "windowTitle").text === "Updated title", "title updates while the same window stays focused");
                    const details = {};
                    popup.details.forEach(row => details[row.label] = row.value);
                    check(details["Size"] === "900 × 600" && details["Process ID"] === "5678", "metadata updates live");
                    Hyprland.activeToplevel = null;
                } else if (step === 4) {
                    check(popup.targetWindow === root.unknown && WindowState.inspectionAvailable, "panel focus preserves the last application");
                    click(button);
                    check(!popup.visible, "repeat click toggles closed");
                    Hyprland.activeToplevel = root.terminal;
                    click(button);
                } else if (step === 5) {
                    check(popup.visible && popup.targetWindow === root.terminal, "reopening follows current focus");
                    Hyprland.toplevels = {values: [root.unknown]};
                    Hyprland.activeToplevel = root.unknown;
                } else if (step === 6) {
                    check(popup.targetWindow === root.unknown && WindowState.inspectionAvailable, "closing a window follows the new focused application");
                    Hyprland.toplevels = {values: []};
                    Hyprland.activeToplevel = null;
                } else if (step === 7) {
                    check(!WindowState.inspectionAvailable, "closed window is no longer available");
                    check(find(popup.contentItem, "windowUnavailable").visible, "closed window has empty state");
                    events.mouseClick(popup.contentItem, 20, popup.height - 20,
                        Qt.LeftButton, Qt.NoModifier, 0);
                    check(!popup.visible && ShellState.panel === "", "outside mouse click dismisses window details");
                    Hyprland.toplevels = {values: [root.terminal]};
                    Hyprland.activeToplevel = root.terminal;
                    click(button);
                } else if (step === 8) {
                    check(popup.visible && WindowState.inspectionAvailable, "window details reopen after outside dismissal");
                    const body = popup.contentItem.children.find(item => item.radius !== undefined);
                    events.mouseClick(body, body.width - 5, body.height - 5,
                        Qt.LeftButton, Qt.NoModifier, 0);
                    check(popup.visible, "inside padding does not dismiss window details");
                    events.touchEvent(popup.contentItem)
                        .press(0, popup.contentItem, 20, popup.height - 20).commit();
                } else if (step === 9) {
                    events.touchEvent(popup.contentItem)
                        .release(0, popup.contentItem, 20, popup.height - 20).commit();
                } else if (step === 10) {
                    check(!popup.visible && ShellState.panel === "", "outside touch dismisses window details");
                    Hyprland.activeToplevel = null;
                } else {
                    check(button.text === "Desktop" && !button.enabled, "empty desktop fallback");
                    check(WindowState.applicationFor(null).icon === "", "no app icon on empty desktop");
                    console.log("WINDOW_DETAILS_PASS");
                    Qt.quit();
                }
                step++;
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''')
            assert_qml_passes(self, root, "WINDOW_DETAILS_PASS")


if __name__ == "__main__":
    unittest.main()
