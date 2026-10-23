#!/usr/bin/env python3
"""List wallpaper files and apply one to each active Hyprland monitor."""
import json
from pathlib import Path
import subprocess
import sys


WALLPAPER_DIR = (Path.home() / "Pictures" / "Wallpapers").resolve()
FORMATS = {".jpg", ".jpeg", ".png", ".webp", ".jxl"}


def wallpaper_path(path_text):
    """Use the same path checks when listing and applying wallpapers."""
    path = Path(path_text).expanduser().resolve(strict=True)
    if path.parent != WALLPAPER_DIR or not path.is_file() or path.suffix.lower() not in FORMATS:
        raise ValueError("Choose an image from ~/Pictures/Wallpapers.")
    # hyprpaper's wallpaper argument is a comma-separated protocol.
    if "," in str(path):
        raise ValueError("Wallpaper paths cannot contain commas (hyprpaper separator).")
    return path


def list_wallpapers():
    if not WALLPAPER_DIR.is_dir():
        raise RuntimeError(f"Wallpaper folder not found: {WALLPAPER_DIR}")
    files = []
    for path in WALLPAPER_DIR.iterdir():
        try:
            wallpaper_path(path)
        except (OSError, ValueError, RuntimeError):
            continue
        files.append(path)
    files.sort(key=lambda path: path.name.casefold())
    print(json.dumps([{"name": path.stem, "path": str(path)} for path in files]))


def set_wallpaper(path_text):
    path = wallpaper_path(path_text)
    monitors = json.loads(subprocess.run(
        ["hyprctl", "monitors", "-j"], check=True, capture_output=True, text=True,
    ).stdout)
    if not monitors:
        raise RuntimeError("Hyprland did not report any active monitors.")
    for monitor in monitors:
        try:
            subprocess.run(
                ["hyprctl", "hyprpaper", "wallpaper", f"{monitor['name']},{path},cover"],
                check=True, capture_output=True, text=True,
            )
        except subprocess.CalledProcessError as error:
            detail = error.stderr.strip() or str(error)
            raise RuntimeError(f"Could not set wallpaper on {monitor['name']}: {detail}") from error


def main():
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "list":
            list_wallpapers()
        elif len(sys.argv) == 3 and sys.argv[1] == "set":
            set_wallpaper(sys.argv[2])
        else:
            raise RuntimeError("Usage: wallpapers.py list | set IMAGE_PATH")
    except (OSError, ValueError, subprocess.CalledProcessError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
