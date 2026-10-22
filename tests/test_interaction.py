"""Exercise delayed hints and button input in an isolated offscreen shell."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class InteractionTests(unittest.TestCase):
    def test_outside_mouse_touch_and_switching_from_bar(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "runtime").mkdir(mode=0o700)
            (root / "components").mkdir()
            (root / "widgets").mkdir()
            for name in ("ActionButton", "IconButton", "Icon", "Label", "PanelFrame"):
                shutil.copy(ROOT / "components" / f"{name}.qml", root / "components")
            for name in ("Bar", "WorkspaceSwitcher"):
                shutil.copy(ROOT / "widgets" / f"{name}.qml", root / "widgets")
            for name in ("Theme.qml", "Config.qml", "ShellState.qml", "qmldir"):
                shutil.copy(ROOT / name, root / name)
            # Only swap the native window shell: retain real hit testing, layout,
            # buttons and panel state. Layer-shell needs a desktop compositor.
            for name in ("components/PanelFrame.qml", "widgets/Bar.qml"):
                path = root / name
                source = path.read_text().replace("PanelWindow {", "FloatingWindow {")
                source = re.sub(
                    r"^    (?:anchors\.(?:top|bottom|left|right):|margins\.|exclusionMode:|exclusiveZone:|WlrLayershell\.).*\n",
                    "", source, flags=re.M,
                )
                if name == "widgets/Bar.qml":
                    source = source.replace("implicitHeight: Config.barHeight",
                                            "implicitWidth: 800\n    implicitHeight: Config.barHeight")
                path.write_text(source)
            services = root / "services"
            services.mkdir()
            (services / "qmldir").write_text(
                "singleton Audio 1.0 Audio.qml\nsingleton NetworkState 1.0 NetworkState.qml\n"
            )
            (services / "Audio.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property string icon: "volume"
    property real volume: 0.5
    property bool muted: false
}
''')
            (services / "NetworkState.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property string icon: "wifi"
    property string status: "Connected"
    property bool limited: false
}
''')
            (root / "shell.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import "components"
import "widgets"
ShellRoot {
    Bar { id: bar; modelData: Quickshell.screens[0] }
    PanelFrame {
        id: launcher
        panelName: "launcher"
        centered: true
        panelWidth: 240
        panelHeight: 200
        ActionButton {
            id: inside
            x: 20; y: 20
            text: "Inside"
            property int clicks: 0
            onClicked: clicks++
        }
    }
    PanelFrame { id: audio; panelName: "audio"; panelWidth: 240; panelHeight: 200 }
    TestEvent { id: events }
    Timer {
        property int step: 0
        interval: 120
        repeat: true
        running: true
        function check(value, message) { if (!value) throw new Error(message); }
        function findIcon(item, name) {
            if (item.iconName === name) return item;
            for (const child of item.children || []) {
                const found = findIcon(child, name);
                if (found) return found;
            }
            return null;
        }
        function click(item, x, y) {
            events.mouseClick(item, x, y, Qt.LeftButton, Qt.NoModifier, 0);
        }
        onTriggered: {
            try {
                const apps = findIcon(bar.contentItem, "apps");
                const volume = findIcon(bar.contentItem, "volume");
                if (step === 0) {
                    click(apps, 15, 14);
                } else if (step === 1) {
                    check(launcher.visible, "bar opens launcher");
                    click(inside, 10, 10);
                    check(inside.clicks === 1 && launcher.visible, "inside control works without dismissing");
                    click(inside.parent, 5, 5);
                    check(launcher.visible, "empty panel padding does not dismiss");
                    click(volume, 15, 14);
                } else if (step === 2) {
                    check(audio.visible && !launcher.visible, "another bar icon switches panels in one click");
                    click(audio.contentItem, audio.width / 2, audio.height - 20);
                    check(ShellState.panel === "", "outside mouse click closes panel");
                    click(apps, 15, 14);
                } else if (step === 3) {
                    check(launcher.visible, "panel reopens after dismissal");
                    events.touchEvent(launcher.contentItem)
                        .press(0, launcher.contentItem, 20, launcher.height - 20).commit();
                } else if (step === 4) {
                    events.touchEvent(launcher.contentItem)
                        .release(0, launcher.contentItem, 20, launcher.height - 20).commit();
                } else if (step === 5) {
                    check(ShellState.panel === "", "outside touch closes panel");
                    click(apps, 15, 14);
                } else if (step === 6) {
                    click(bar.contentItem, bar.width / 2, 18);
                    check(ShellState.panel === "", "empty bar click closes panel");
                    click(volume, 15, 14);
                } else {
                    check(audio.visible, "bar still works after repeated dismissals");
                    click(volume, 15, 14);
                    check(ShellState.panel === "", "active icon toggles panel closed");
                    console.log("POPUP_INPUT_PASS");
                    Qt.quit();
                }
                step++;
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''')
            env = dict(os.environ)
            for key in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
                env.pop(key, None)
            env.update(QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=str(root / "runtime"),
                       XDG_CACHE_HOME=str(root / "cache"))
            result = subprocess.run(
                ["quickshell", "-p", str(root), "--no-color"],
                env=env, capture_output=True, text=True, timeout=12,
            )
            output = result.stdout + result.stderr
            self.assertIn("POPUP_INPUT_PASS", output, output)
            self.assertNotIn("TEST FAILURE", output, output)

    def test_click_after_hover_without_leaving_icon(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "runtime").mkdir(mode=0o700)
            (root / "components").mkdir()
            for name in ("ActionButton.qml", "IconButton.qml", "Icon.qml", "Label.qml"):
                shutil.copy(ROOT / "components" / name, root / "components" / name)
            for name in ("Theme.qml", "Config.qml", "ShellState.qml", "qmldir"):
                shutil.copy(ROOT / name, root / name)
            (root / "shell.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import "components"

ShellRoot {
    FloatingWindow {
        id: window
        implicitWidth: 320
        implicitHeight: 160
        IconButton {
            id: button
            x: 20; y: 20
            hint: "Applications"
            focusPolicy: Qt.NoFocus
            property int clicks: 0
            onClicked: clicks++
        }
        TextInput { id: input; x: 20; y: 80; width: 200; height: 30 }
        TestEvent { id: events }
        Timer {
            property int step: 0
            interval: 900
            repeat: true
            running: true
            function check(value, message) { if (!value) throw new Error(message); }
            onTriggered: {
                try {
                    const hint = button.data.find(child => child.grabFocus !== undefined);
                    check(hint !== undefined, "hint window exists");
                    if (step === 0) {
                        input.forceActiveFocus();
                        events.mouseMove(button, 15, 14, 0, Qt.NoButton, Qt.NoModifier);
                    } else if (step === 1) {
                        check(hint.backingWindowVisible, "hint appears after hover delay");
                        check(button.hovered, "hint preserves hover");
                        check(input.activeFocus, "hint preserves keyboard focus");
                        check(!hint.grabFocus && hint.mask.width === 0 && hint.mask.height === 0,
                            "hint has no focus grab or input region");
                        events.mouseClick(button, 15, 14, Qt.LeftButton, Qt.NoModifier, 0);
                        check(button.clicks === 1, "first click after hover is delivered");
                    } else if (step === 2) {
                        events.mouseClick(button, 15, 14, Qt.LeftButton, Qt.NoModifier, 0);
                        check(button.clicks === 2, "second click needs no pointer reset");
                        ShellState.toggle("launcher", window.screen, 35);
                        check(ShellState.panelAnchorX === 35, "bar anchor is preserved");
                    } else if (step === 3) {
                        check(!hint.visible, "open panel suppresses stale bar hint");
                        ShellState.close();
                        events.mouseMove(window.contentItem, 280, 120, 0, Qt.NoButton, Qt.NoModifier);
                    } else {
                        check(!hint.visible, "leaving icon cancels pending hint");
                        console.log("HOVER_CLICK_PASS");
                        Qt.quit();
                    }
                    step++;
                } catch (error) {
                    console.log("TEST FAILURE", error.message);
                    Qt.quit();
                }
            }
        }
    }
}
''')
            env = dict(os.environ)
            for key in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
                env.pop(key, None)
            env.update(
                QT_QPA_PLATFORM="offscreen",
                XDG_RUNTIME_DIR=str(root / "runtime"),
                XDG_CACHE_HOME=str(root / "cache"),
            )
            result = subprocess.run(
                ["quickshell", "-p", str(root), "--no-color"],
                env=env, capture_output=True, text=True, timeout=12,
            )
            output = result.stdout + result.stderr
            self.assertIn("HOVER_CLICK_PASS", output, output)
            self.assertNotIn("TEST FAILURE", output, output)


if __name__ == "__main__":
    unittest.main()
