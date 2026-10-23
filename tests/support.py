"""Run QML checks without using the desktop's state, services, or working directory."""
import os
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def floating_window(source):
    """Keep panel contents while replacing compositor-only window properties."""
    source = source.replace("PanelWindow {", "FloatingWindow {")
    return re.sub(
        r"^    (?:anchors\.(?:top|bottom|left|right):|margins\.|exclusionMode:|exclusiveZone:|WlrLayershell\.).*"
        r"(?:\n[ \t]{8,}[^\n]*)*\n",
        "", source, flags=re.M,
    )
def qml_environment(root):
    (root / "runtime").mkdir(mode=0o700, exist_ok=True)
    env = dict(os.environ)
    for key in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "QS_CONFIG_PATH",
                "QS_CONFIG_NAME", "QS_MANIFEST"):
        env.pop(key, None)
    env.update(
        QT_QPA_PLATFORM="offscreen",
        QML_DISABLE_DISK_CACHE="1",
        XDG_RUNTIME_DIR=str(root / "runtime"),
        XDG_CACHE_HOME=str(root / "cache"),
        XDG_CONFIG_HOME=str(root / "config"),
        XDG_STATE_HOME=str(root / "state"),
        DBUS_SESSION_BUS_ADDRESS=f"unix:path={root}/no-session-bus",
        DBUS_SYSTEM_BUS_ADDRESS=f"unix:path={root}/no-system-bus",
    )
    return env


def assert_qml_passes(test, root, marker, env=None, timeout=10):
    result = subprocess.run(
        ["quickshell", "-p", str(root), "--no-color"],
        cwd=root.parent, env=env or qml_environment(root),
        capture_output=True, text=True, timeout=timeout,
    )
    output = result.stdout + result.stderr
    test.assertEqual(result.returncode, 0, output)
    test.assertIn(marker, output, output)
    for failure in ("TEST FAILURE", "TypeError:", "ReferenceError:"):
        test.assertNotIn(failure, output, output)
