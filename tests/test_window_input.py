"""Check passive popup input, event validation and temporary-binding cleanup."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from support import ROOT, assert_qml_passes, qml_environment


class WindowInputLuaTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua"), "lua is required")
    def test_bindings_are_passive_scoped_and_removed_without_touching_user_bindings(self):
        harness = r'''
local source = assert(io.open(arg[1])):read("*a")
local handles, events, subscriptions = {}, {}, {}
local bars = {}
hl = {
    bind = function(key, callback, options)
        assert(options.non_consuming and options.ignore_mods and options.submap_universal)
        local handle = { key = key, callback = callback, removed = false }
        function handle:remove() self.removed = true end
        table.insert(handles, handle)
        return handle
    end,
    get_cursor_pos = function() return {x = -123, y = 456} end,
    get_layers = function() return bars end,
    on = function(name, callback)
        assert(name == "layer.closed")
        local handle = { callback = callback, removed = false }
        function handle:remove() self.removed = true end
        table.insert(subscriptions, handle)
        return handle
    end,
    dsp = {event = function(data) return data end},
    dispatch = function(data) table.insert(events, data) end,
}
local function run(key, token, enabled)
    assert(load(string.format("local key=%q; local token=%q; local enabled=%s;\n", key, token, tostring(enabled)) .. source))()
end
run("shell", "first", true)
assert(#handles == 3)
handles[1].callback()
assert(events[1] == "first,-123,456")
bars = {{x = -200, y = 450, w = 100, h = 36}}
handles[1].callback()
assert(#events == 1, "bar buttons must handle their own toggles")
bars = {}
run("other-shell", "other", true)
run("shell", "second", true)
for i = 1, 3 do assert(handles[i].removed) end
for i = 4, 9 do assert(not handles[i].removed) end
run("shell", "first", false) -- A late cleanup must not remove a new popup's bindings.
for i = 7, 9 do assert(not handles[i].removed) end
run("shell", "second", false)
for i = 7, 9 do assert(handles[i].removed) end
for i = 4, 6 do assert(not handles[i].removed) end
run("other-shell", "other", false)
for i = 4, 6 do assert(handles[i].removed) end
run("cat-window-7", "crashed", true)
subscriptions[#subscriptions].callback({namespace = "cat-panel", pid = 8})
for i = 10, 12 do assert(not handles[i].removed) end
subscriptions[#subscriptions].callback({namespace = "cat-panel", pid = 7})
for i = 10, 12 do assert(handles[i].removed) end
assert(subscriptions[#subscriptions].removed, "layer disappearance also removes the cleanup subscription")
print("WINDOW_INPUT_LUA_PASS")
'''
        result = subprocess.run(["lua", "-", str(ROOT / "scripts/window-input.lua")],
                                input=harness, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("WINDOW_INPUT_LUA_PASS", result.stdout)


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class WindowInputTests(unittest.TestCase):
    def test_activation_events_quick_reopening_and_failed_installation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("services", "scripts", "fake", "bin"):
                (root / name).mkdir()
            source = (ROOT / "services/WindowInput.qml").read_text()
            (root / "services/WindowInput.qml").write_text(source.replace(
                "import Quickshell.Hyprland", 'import "../fake"'))
            (root / "services/qmldir").write_text("singleton WindowInput 1.0 WindowInput.qml\n")
            shutil.copy(ROOT / "scripts/window-input.lua", root / "scripts")
            (root / "fake/qmldir").write_text("singleton Hyprland 1.0 Hyprland.qml\n")
            (root / "fake/Hyprland.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property bool usingLua: true
    signal rawEvent(var event)
}
''')
            backend = root / "bin/hyprctl"
            backend.write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
import time
time.sleep(0.04)
if Path(os.environ["INPUT_FAIL_FILE"]).exists():
    sys.exit(1)
with open(os.environ["INPUT_COMMAND_LOG"], "a") as log:
    log.write("start\\n" if "local enabled = true" in sys.argv[2] else "stop\\n")
''')
            backend.chmod(0o755)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "fake"
ShellRoot {
    id: root
    property int received: 0
    property real lastX: 0
    property real lastY: 0
    Connections {
        target: WindowInput
        function onPressed(x, y) { root.received++; root.lastX = x; root.lastY = y; }
    }
    FileView { id: failure; path: Quickshell.env("INPUT_FAIL_FILE"); printErrors: false }
    Component.onCompleted: WindowInput.active = true
    Timer {
        property int step: 0
        property int retries: 0
        interval: 160
        repeat: true
        running: true
        function check(value, message) { if (!value) throw new Error(message); }
        onTriggered: {
            try {
                if (step <= 2 && !WindowInput.ready) {
                    check(++retries < 20, "listener activation completes");
                    return;
                }
                retries = 0;
                if (step === 0) {
                    check(WindowInput.ready, "listener is acknowledged before enabling pass-through");
                    Hyprland.rawEvent({name: "custom", data: WindowInput.token + ",-123,456"});
                    check(root.received === 1 && root.lastX === -123 && root.lastY === 456, "global coordinates forwarded, including negative monitor positions");
                    for (const data of ["stale,1,2", WindowInput.token + ",bad,2", WindowInput.token + ",1,2,3"])
                        Hyprland.rawEvent({name: "custom", data: data});
                    Hyprland.rawEvent({name: "other", data: WindowInput.token + ",1,2"});
                    check(root.received === 1, "unrelated and malformed events ignored");
                    WindowInput.active = false;
                    check(!WindowInput.ready, "closing immediately disables pass-through");
                    WindowInput.active = true;
                } else if (step === 1) {
                    check(WindowInput.ready, "fast close and reopen installs current listener");
                    Hyprland.rawEvent({name: "configreloaded", data: ""});
                    check(!WindowInput.ready, "compositor reload disables pass-through until listener is restored");
                } else if (step === 2) {
                    check(WindowInput.ready, "listener recovers after compositor reload");
                    failure.setText("fail");
                    WindowInput.active = false;
                } else if (step === 3) {
                    WindowInput.active = true;
                } else if (step === 4) {
                    check(!WindowInput.ready, "failed listener keeps standard outside-click overlay");
                    Hyprland.rawEvent({name: "custom", data: WindowInput.token + ",1,2"});
                    check(root.received === 1, "events ignored after failed installation");
                    WindowInput.active = false;
                } else {
                    console.log("WINDOW_INPUT_PASS");
                    Qt.quit();
                }
                step++;
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''')
            env = qml_environment(root)
            env["PATH"] = str(root / "bin") + ":" + env["PATH"]
            env["INPUT_COMMAND_LOG"] = str(root / "commands.log")
            env["INPUT_FAIL_FILE"] = str(root / "fail")
            assert_qml_passes(self, root, "WINDOW_INPUT_PASS", env)
            commands = (root / "commands.log").read_text().splitlines()
            self.assertEqual(commands[:3], ["start", "stop", "start"])


if __name__ == "__main__":
    unittest.main()
