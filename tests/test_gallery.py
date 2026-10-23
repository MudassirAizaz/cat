"""Exercise lazy gallery lifecycle, selection, scrolling and keyboard controls."""
from pathlib import Path
import shutil
import tempfile
import unittest

from support import ROOT, assert_qml_passes, floating_window


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class GalleryTests(unittest.TestCase):
    def test_gallery_releases_views_and_preserves_navigation_on_reopen(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT / "components", root / "components")
            (root / "panels").mkdir()
            shutil.copy(ROOT / "panels/WallpaperPanel.qml", root / "panels")
            for name in ("Config.qml", "Theme.qml", "ShellState.qml", "qmldir"):
                shutil.copy(ROOT / name, root / name)
            frame = root / "components/PanelFrame.qml"
            frame.write_text(floating_window(frame.read_text()))
            (root / "services").mkdir()
            (root / "services/qmldir").write_text("singleton WallpaperState 1.0 WallpaperState.qml\n")
            (root / "services/WallpaperState.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var wallpapers: []
    property bool busy: false
    property string error: ""
    property string currentPath: ""
    property string pendingPath: ""
    property int refreshes: 0
    property int applications: 0
    function refresh() {
        refreshes++;
        Qt.callLater(() => wallpapers = wallpapers.map(entry => ({name: entry.name, path: entry.path})));
    }
    function set(path) { currentPath = path; applications++; }
}
''')
            images = root / "images"
            images.mkdir()
            for index in range(40):
                (images / f"wallpaper {index}.svg").write_text(
                    '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">'
                    '<rect width="200" height="100" fill="#a7c080"/></svg>')
            (root / "shell.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import "panels"
import "services"
ShellRoot {
    WallpaperPanel { id: popup }
    TestEvent { id: events }
    Component.onCompleted: {
        const entries = [];
        for (let i = 0; i < 40; i++)
            entries.push({name: "Wallpaper " + i, path: Quickshell.shellPath("images/wallpaper " + i + ".svg")});
        WallpaperState.wallpapers = entries;
        ShellState.toggle("wallpaper");
    }
    Timer {
        property int step: 0
        property int savedIndex: -1
        property real savedY: 0
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
        onTriggered: {
            try {
                const loader = find(popup.contentItem, "wallpaperGalleryLoader");
                const gallery = loader.item;
                if (step === 0) {
                    check(popup.visible && gallery && gallery.count === 40, "gallery loads on open");
                    check(gallery.activeFocus, "gallery takes keyboard focus");
                    events.keyClick(Qt.Key_Right, Qt.NoModifier, 0);
                } else if (step === 1) {
                    check(gallery.currentIndex === 1, "arrow navigation works");
                    gallery.currentIndex = 18;
                    gallery.positionViewAtIndex(18, GridView.Beginning);
                } else if (step === 2) {
                    savedIndex = gallery.currentIndex;
                    savedY = gallery.contentY;
                    check(savedY > 0, "gallery scrolled to a later row");
                    ShellState.close();
                } else if (step === 3) {
                    check(!loader.active && !gallery, "hidden gallery releases its view and delegates");
                    ShellState.toggle("wallpaper");
                } else if (step === 4) {
                    check(gallery.currentIndex === savedIndex, "selection survives reopening");
                    check(Math.abs(gallery.contentY - savedY) < 1, "scroll position survives reopening");
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                } else if (step === 5) {
                    check(WallpaperState.applications === 1 && WallpaperState.currentPath === WallpaperState.wallpapers[savedIndex].path, "Enter applies selected wallpaper through service");
                    check(popup.visible, "applying wallpaper leaves gallery open");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                } else if (step === 6) {
                    check(!popup.visible && !loader.item, "Escape closes and releases gallery");
                    ShellState.toggle("menu");
                    ShellState.navigate("wallpaper");
                } else if (step === 7) {
                    check(popup.visible && gallery.currentIndex === savedIndex, "menu navigation restores selection");
                    events.keyClick(Qt.Key_Backspace, Qt.NoModifier, 0);
                } else if (step === 8) {
                    check(ShellState.panel === "menu" && !loader.item, "Backspace returns to menu and releases view");
                    ShellState.forward();
                } else {
                    check(popup.visible && loader.item.currentIndex === savedIndex, "forward navigation reloads gallery correctly");
                    check(WallpaperState.refreshes >= 4, "open still refreshes wallpaper listing");
                    ShellState.close();
                    console.log("GALLERY_PASS");
                    Qt.quit();
                }
                step++;
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''')
            assert_qml_passes(self, root, "GALLERY_PASS")


if __name__ == "__main__":
    unittest.main()
