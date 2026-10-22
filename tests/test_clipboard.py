"""Exercise the actual cliphist database without accessing the desktop clipboard."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "scripts" / "clipboard.sh"


@unittest.skipUnless(shutil.which("cliphist"), "cliphist is required")
class ClipboardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "copied"
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        copier = bin_dir / "wl-copy"
        copier.write_text('#!/bin/sh\ncat > "$CAT_TEST_COPY"\n')
        copier.chmod(0o755)
        self.env = dict(os.environ)
        # Ignore any host cliphist options and never touch its database.
        for key in tuple(self.env):
            if key.startswith("CLIPHIST_"):
                del self.env[key]
        self.env.update(
            XDG_CACHE_HOME=str(self.root / "cache"),
            XDG_CONFIG_HOME=str(self.root / "config"),
            PATH=f"{bin_dir}:{os.environ['PATH']}",
            CAT_TEST_COPY=str(self.output),
        )

    def helper(self, *args, check=True):
        return subprocess.run(
            ["bash", str(HELPER), *args], env=self.env,
            capture_output=True, check=check,
        )

    def store(self, value):
        subprocess.run(["cliphist", "store"], input=value, env=self.env, check=True)
        return self.helper("list").stdout.split(b"\t", 1)[0].decode()

    def test_fresh_database_is_empty(self):
        self.assertEqual(self.helper("list").stdout, b"")

    def test_text_and_shell_metacharacters_are_data(self):
        marker = self.root / "must-not-exist"
        text = f"first line\n$(touch {marker}) `touch {marker}` 'quoted'\t☀\n\n".encode()
        entry = self.store(text)
        self.helper("copy", entry)
        self.assertEqual(self.output.read_bytes(), text)
        self.assertFalse(marker.exists())

    def test_binary_copy_preserves_every_byte(self):
        data = b"\x89PNG\r\n\x1a\n" + bytes(range(256))
        entry = self.store(data)
        self.helper("copy", entry)
        self.assertEqual(self.output.read_bytes(), data)

    def test_missing_entry_does_not_overwrite_clipboard(self):
        self.store(b"available")
        self.output.write_bytes(b"keep this")
        self.assertNotEqual(self.helper("copy", "999999", check=False).returncode, 0)
        self.assertEqual(self.output.read_bytes(), b"keep this")

    def test_invalid_ids_are_rejected(self):
        for value in ("", "1; touch ignored", "$(id)", "-1", "1\n2"):
            self.assertNotEqual(self.helper("copy", value, check=False).returncode, 0)
        self.assertFalse(self.output.exists())

    def test_delete_and_clear(self):
        entry = self.store(b"first entry")
        self.store(b"second entry")
        self.helper("delete", entry)
        self.assertNotIn(b"first entry", self.helper("list").stdout)
        self.assertIn(b"second entry", self.helper("list").stdout)
        self.helper("wipe")
        self.assertEqual(self.helper("list").stdout, b"")


if __name__ == "__main__":
    unittest.main()
