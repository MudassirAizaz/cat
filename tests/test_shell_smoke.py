"""Load every panel from a relocated checkout using isolated offscreen windows."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from support import ROOT, floating_window, qml_environment


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class ShellSmokeTests(unittest.TestCase):
    def test_relocated_shell_and_all_panels_load_from_another_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            checkout = temporary / "Cat's relocated checkout ☀ with spaces"
            shutil.copytree(ROOT, checkout, ignore=shutil.ignore_patterns(
                ".git", ".agents", ".aws", ".codex", "__pycache__",
            ))
            for path in checkout.rglob("*.qml"):
                source = path.read_text()
                if "PanelWindow {" in source:
                    path.write_text(floating_window(source))

            entrypoint = checkout / "shell.qml"
            source = entrypoint.read_text()
            source = source.replace("import Quickshell\n", "import QtQuick\nimport Quickshell\n", 1)
            # Use the real composition root, with only native windows swapped out.
            # Exercise opening every panel without launching apps or changing settings.
            timer = '''
    Timer {
        property var panels: ["menu", "launcher", "clipboard", "notifications",
            "audio", "calendar", "window", "power", "network", "session", "theme", "wallpaper"]
        property int index: 0
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            if (index < panels.length) {
                ShellState.toggle(panels[index++]);
            } else {
                ShellState.close();
                console.log("RELOCATED_SHELL_PASS");
                Qt.quit();
            }
        }
    }
'''
            before, closing = source.rsplit("}", 1)
            entrypoint.write_text(before + timer + "}" + closing)
            env = qml_environment(temporary)
            env["HOME"] = str(temporary / "home")
            (Path(env["HOME"]) / "Pictures/Wallpapers").mkdir(parents=True)
            unrelated = temporary / "unrelated"
            unrelated.mkdir()
            launcher = unrelated / "cat-shell"
            launcher.symlink_to(Path("..") / checkout.name / "run.sh")
            result = subprocess.run(
                [str(launcher), "--no-color"], cwd=unrelated, env=env,
                capture_output=True, text=True, timeout=12,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("RELOCATED_SHELL_PASS", output, output)
            for failure in ("Failed to load configuration", "TypeError:", "ReferenceError:",
                            "No such file or directory", "is not installed"):
                self.assertNotIn(failure, output, output)


if __name__ == "__main__":
    unittest.main()
