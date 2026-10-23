"""Exercise wallpaper paths and session dispatch with isolated command backends."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from support import ROOT


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / "Pictures" / "Wallpapers"
        self.folder.mkdir(parents=True)
        spec = importlib.util.spec_from_file_location("wallpapers", ROOT / "scripts/wallpapers.py")
        self.wallpapers = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.wallpapers)
        self.wallpapers.WALLPAPER_DIR = self.folder.resolve()

    def test_list_and_apply_agree_on_allowed_paths(self):
        (self.folder / "B image ☀.png").write_bytes(b"image")
        (self.folder / "a.jpg").write_bytes(b"image")
        (self.folder / "notes.txt").write_text("not an image")
        outside = self.root / "outside.png"
        outside.write_bytes(b"image")
        (self.folder / "outside.png").symlink_to(outside)
        (self.folder / "broken.png").symlink_to(self.root / "missing.png")
        (self.folder / "comma,image.png").write_bytes(b"image")
        output = io.StringIO()
        with redirect_stdout(output):
            self.wallpapers.list_wallpapers()
        entries = json.loads(output.getvalue())
        self.assertEqual([entry["name"] for entry in entries], ["a", "B image ☀"])
        for entry in entries:
            self.assertEqual(self.wallpapers.wallpaper_path(entry["path"]), Path(entry["path"]))

    def test_apply_uses_argument_arrays_for_each_monitor(self):
        image = self.folder / "a 'quoted' image ☀.png"
        image.write_bytes(b"image")
        monitors = subprocess.CompletedProcess([], 0, stdout='[{"name":"DP-1"},{"name":"HDMI-A-1"}]')
        with patch.object(self.wallpapers.subprocess, "run", side_effect=[monitors, None, None]) as run:
            self.wallpapers.set_wallpaper(str(image))
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands, [
            ["hyprctl", "monitors", "-j"],
            ["hyprctl", "hyprpaper", "wallpaper", f"DP-1,{image},cover"],
            ["hyprctl", "hyprpaper", "wallpaper", f"HDMI-A-1,{image},cover"],
        ])

    def test_rejects_outside_paths_and_protocol_separators(self):
        outside = self.root / "outside.png"
        outside.write_bytes(b"image")
        comma = self.folder / "comma,image.png"
        comma.write_bytes(b"image")
        for image in (outside, comma):
            with self.subTest(image=image), self.assertRaises(ValueError):
                self.wallpapers.wallpaper_path(str(image))

    def test_partial_application_reports_the_failing_monitor(self):
        image = self.folder / "image.png"
        image.write_bytes(b"image")
        monitors = subprocess.CompletedProcess([], 0, stdout='[{"name":"DP-1"},{"name":"DP-2"}]')
        failure = subprocess.CalledProcessError(1, ["hyprctl"], stderr="IPC unavailable")
        with patch.object(self.wallpapers.subprocess, "run", side_effect=[monitors, None, failure]):
            with self.assertRaisesRegex(RuntimeError, "DP-2: IPC unavailable"):
                self.wallpapers.set_wallpaper(str(image))

    def test_cli_uses_home_from_an_unrelated_working_directory(self):
        helper = self.root / "checkout with spaces" / "wallpapers.py"
        helper.parent.mkdir()
        shutil.copy(ROOT / "scripts/wallpapers.py", helper)
        image = self.folder / "image.png"
        image.write_bytes(b"image")
        result = subprocess.run(
            [sys.executable, str(helper), "list"], cwd=helper.parent,
            env=dict(os.environ, HOME=str(self.root)), capture_output=True, text=True, check=True,
        )
        self.assertEqual(json.loads(result.stdout), [{"name": "image", "path": str(image)}])


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, PATH=str(self.root))
        self.helper = ROOT / "scripts/session.sh"

    def command(self, name, fail_lua=False):
        binary = self.root / name
        binary.write_text(
            f"#!{sys.executable}\nimport json, sys\n"
            "print(json.dumps(sys.argv[1:]))\n"
            + ("sys.exit(1 if sys.argv[-1] == 'hl.dsp.exit()' else 0)\n" if fail_lua else "")
        )
        binary.chmod(0o755)

    def invoke(self, action):
        return subprocess.run(
            [shutil.which("bash"), str(self.helper), action], cwd=self.root,
            env=self.env, capture_output=True, text=True,
        )

    def test_system_actions_are_allowlisted_and_forwarded(self):
        self.command("systemctl")
        for action in ("suspend", "hibernate", "reboot", "poweroff"):
            with self.subTest(action=action):
                result = self.invoke(action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), [action])
        self.assertEqual(self.invoke("poweroff; ignored").returncode, 2)

    def test_logout_prefers_hyprshutdown(self):
        self.command("hyprshutdown")
        self.assertEqual(self.invoke("logout").stdout.strip(), "[]")

    def test_logout_falls_back_from_lua_to_legacy_dispatch(self):
        self.command("hyprctl", fail_lua=True)
        result = self.invoke("logout")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([json.loads(line) for line in result.stdout.splitlines()], [
            ["dispatch", "hl.dsp.exit()"], ["dispatch", "exit"],
        ])


if __name__ == "__main__":
    unittest.main()
