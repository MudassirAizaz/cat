"""Exercise the clock popup and real month navigation without desktop services."""
from pathlib import Path
import shutil
import tempfile
import unittest

from support import ROOT, assert_qml_passes, floating_window


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class CalendarTests(unittest.TestCase):
    def test_clock_toggle_month_boundaries_leap_years_and_today(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ("components", "services", "widgets"):
                shutil.copytree(ROOT / folder, root / folder)
            (root / "panels").mkdir()
            shutil.copy(ROOT / "panels/DateTimePanel.qml", root / "panels")
            for name in ("Config.qml", "Theme.qml", "ShellState.qml", "qmldir"):
                shutil.copy(ROOT / name, root / name)
            for name in ("components/PanelFrame.qml", "widgets/Bar.qml"):
                path = root / name
                path.write_text(floating_window(path.read_text()))

            (root / "shell.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import "panels"
import "widgets"
ShellRoot {
    Bar { id: bar; modelData: Quickshell.screens[0]; implicitWidth: 1000 }
    DateTimePanel { id: popup }
    TestEvent { id: events }
    Timer {
        property int step: 0
        interval: 100
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
        function hasDay(item, year, month, day) {
            if (item.objectName === "calendarDay" && item.model.year === year
                && item.model.month === month && item.model.day === day) return true;
            return (item.children || []).some(child => hasDay(child, year, month, day));
        }
        function click(item) {
            check(!!item, "calendar control exists");
            events.mouseClick(item, item.width / 2, item.height / 2,
                Qt.LeftButton, Qt.NoModifier, 0);
        }
        onTriggered: {
            try {
                const button = find(bar.contentItem, "calendarButton");
                const grid = find(popup.contentItem, "monthGrid");
                if (step === 0) {
                    check(button.visible, "bar clock is visible");
                    click(button);
                } else if (step === 1) {
                    check(popup.visible && ShellState.panelScreen === bar.screen, "clock opens popup on its monitor");
                    check(button.selected, "clock shows selected state");
                    check(find(popup.contentItem, "calendarTime").text === Qt.formatDateTime(popup.now, "HH:mm:ss"), "live time displayed");
                    check(find(popup.contentItem, "calendarDate").text === Qt.formatDateTime(popup.now, "dddd, d MMMM yyyy"), "full date displayed");
                    popup.displayedMonth = new Date(2024, 11, 31);
                } else if (step === 2) {
                    click(find(popup.contentItem, "nextMonth"));
                    check(popup.displayedMonth.getFullYear() === 2025 && popup.displayedMonth.getMonth() === 0, "next crosses year without skipping January");
                } else if (step === 3) {
                    check(grid.year === 2025 && grid.month === 0, "grid follows browsed month");
                    click(find(popup.contentItem, "previousMonth"));
                    check(popup.displayedMonth.getFullYear() === 2024 && popup.displayedMonth.getMonth() === 11, "previous crosses year");
                    popup.displayedMonth = new Date(2024, 1, 1);
                } else if (step === 4) {
                    check(hasDay(grid, 2024, 1, 29), "leap day present in leap year");
                    popup.displayedMonth = new Date(2023, 1, 1);
                } else if (step === 5) {
                    check(!hasDay(grid, 2023, 1, 29), "no leap day in ordinary year");
                    click(find(popup.contentItem, "calendarToday"));
                } else if (step === 6) {
                    const now = new Date();
                    check(grid.year === now.getFullYear() && grid.month === now.getMonth(), "Today restores current month");
                    check(hasDay(grid, now.getFullYear(), now.getMonth(), now.getDate()), "today is in grid");
                    popup.displayedMonth = new Date(2020, 0, 1);
                    click(button);
                    check(!popup.visible, "second clock click closes popup");
                    click(button);
                } else if (step === 7) {
                    const now = new Date();
                    check(popup.visible && grid.year === now.getFullYear() && grid.month === now.getMonth(), "reopening resets month");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                } else {
                    check(!popup.visible && ShellState.panel === "", "Escape closes calendar");
                    console.log("CALENDAR_PASS");
                    Qt.quit();
                }
                step++;
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''')
            assert_qml_passes(self, root, "CALENDAR_PASS")


if __name__ == "__main__":
    unittest.main()
