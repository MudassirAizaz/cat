"""Check launcher paths and argument forwarding without starting a desktop shell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from support import ROOT


class LauncherPathTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.checkout = self.root / "Cat's checkout $with spaces"
        self.checkout.mkdir()
        shutil.copy(ROOT / "run.sh", self.checkout / "run.sh")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        quickshell = self.bin / "quickshell"
        quickshell.write_text(
            '#!/usr/bin/env python3\nimport json, os, sys\n'
            'assert not any(key in os.environ for key in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST"))\n'
            'print(json.dumps(sys.argv[1:]))\n'
        )
        quickshell.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}")
        self.unrelated = self.root / "unrelated working directory"
        self.unrelated.mkdir()

    def invoke(self, launcher, *args):
        result = subprocess.run(
            [str(launcher), *args], cwd=self.unrelated, env=self.env,
            capture_output=True, text=True, check=True,
        )
        return json.loads(result.stdout)

    def test_relocated_checkout_from_another_working_directory(self):
        self.assertEqual(
            self.invoke(self.checkout / "run.sh", "--no-color"),
            ["-p", str(self.checkout), "--no-color"],
        )

    def test_launcher_symlink_on_path_resolves_the_real_checkout(self):
        (self.bin / "cat-shell").symlink_to(self.checkout / "run.sh")
        self.assertEqual(self.invoke("cat-shell"), ["-p", str(self.checkout)])

    def test_relative_symlink_and_ipc_arguments(self):
        launcher = self.unrelated / "cat-shell"
        launcher.symlink_to(Path("..") / self.checkout.name / "run.sh")
        self.assertEqual(
            self.invoke(launcher, "ipc", "call", "shell", "menu"),
            ["ipc", "-p", str(self.checkout), "call", "shell", "menu"],
        )

    def test_arguments_are_forwarded_without_shell_interpretation(self):
        value = "space 'quote' $(touch must-not-exist)"
        self.assertEqual(
            self.invoke(self.checkout / "run.sh", "ipc", "call", "shell", value),
            ["ipc", "-p", str(self.checkout), "call", "shell", value],
        )
        self.assertFalse((self.unrelated / "must-not-exist").exists())

    def test_ambient_quickshell_config_does_not_change_the_checkout(self):
        self.env.update(QS_CONFIG_PATH="elsewhere", QS_CONFIG_NAME="other", QS_MANIFEST="other.conf")
        self.assertEqual(self.invoke(self.checkout / "run.sh"), ["-p", str(self.checkout)])

    @unittest.skipUnless(shutil.which("lua"), "Lua is required")
    def test_hyprland_startup_and_shortcuts_use_the_installed_shell(self):
        shutil.copy(ROOT / "hyprland.lua", self.checkout / "hyprland.lua")
        shutil.copytree(ROOT / "hypr", self.checkout / "hypr")
        active_config = self.unrelated / "hyprland.lua"
        active_config.symlink_to(Path("..") / self.checkout.name / "hyprland.lua")
        home = self.root / "User's home $with spaces"
        installed = home / ".local/bin/cat-shell"
        installed.mkdir(parents=True)
        shutil.copy(ROOT / "run.sh", installed / "run.sh")
        env = dict(self.env, HOME=str(home))
        # Record startup and binding commands without executing desktop actions.
        harness = '''
local dispatcher = {}
setmetatable(dispatcher, {
    __index = function(self) return self end,
    __call = function(_, command) return command end
})
hl = setmetatable({
    dsp = dispatcher,
    on = function(event, callback)
        if event == "hyprland.start" then callback() end
    end,
    exec_cmd = function(command) print("STARTUP\\t" .. command) end,
    bind = function(key, command)
        if key:match("^SUPER") and type(command) == "string"
            and command:find(" ipc call shell ", 1, true) then
            print(key .. "\\t" .. command)
        end
        return {}
    end
}, { __index = function() return function() return {} end end })
dofile(arg[1])
'''
        result = subprocess.run(
            ["lua", "-", str(active_config)], input=harness,
            cwd=self.unrelated, env=env, capture_output=True, text=True, check=True,
        )
        commands = [line.split("\t", 1) for line in result.stdout.splitlines()]
        startup = [command for key, command in commands if key == "STARTUP"]
        bindings = {key: command for key, command in commands if key != "STARTUP"}
        self.assertIn("hyprpaper", startup)
        self.assertFalse(any("waybar" in command for command in startup))
        call = subprocess.run(
            ["bash", "-c", startup[0]], cwd=self.unrelated, env=env,
            capture_output=True, text=True, check=True,
        )
        self.assertEqual(json.loads(call.stdout), ["-p", str(installed)])
        actions = {
            "SUPER + R": "launcher", "SUPER + SPACE": "menu", "SUPER + P": "session",
            "SUPER + V": "clipboard", "SUPER + N": "notifications", "SUPER + SHIFT + N": "dnd",
        }
        self.assertEqual(bindings.keys(), actions.keys())
        for key, action in actions.items():
            with self.subTest(key=key):
                call = subprocess.run(
                    ["bash", "-c", bindings[key]], cwd=self.unrelated, env=env,
                    capture_output=True, text=True, check=True,
                )
                self.assertEqual(json.loads(call.stdout), [
                    "ipc", "-p", str(installed), "call", "shell", action,
                ])


if __name__ == "__main__":
    unittest.main()
