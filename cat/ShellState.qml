pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    property string panel: ""
    property var panelScreen: null
    property real panelAnchorX: -1
    property var backHistory: []
    property var forwardHistory: []
    readonly property bool canGoBack: backHistory.length > 0
    readonly property bool canGoForward: forwardHistory.length > 0
    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0] || null;
    }

    function toggle(name, screen, anchorX) {
        if (panel === name && (!screen || panelScreen === screen)) {
            close();
        } else {
            backHistory = [];
            forwardHistory = [];
            panelScreen = screen || focusedScreen;
            panelAnchorX = anchorX === undefined ? -1 : anchorX;
            panel = name;
        }
    }

    function navigate(name) {
        if (name === panel)
            return;
        if (!panelScreen)
            panelScreen = focusedScreen;
        if (panel)
            backHistory = backHistory.concat([panel]);
        forwardHistory = [];
        panel = name;
    }

    function back() {
        if (!canGoBack)
            return false;
        forwardHistory = forwardHistory.concat([panel]);
        const previous = backHistory[backHistory.length - 1];
        backHistory = backHistory.slice(0, -1);
        panel = previous;
        return true;
    }

    function forward() {
        if (!canGoForward)
            return false;
        backHistory = backHistory.concat([panel]);
        const next = forwardHistory[forwardHistory.length - 1];
        forwardHistory = forwardHistory.slice(0, -1);
        panel = next;
        return true;
    }

    function handleNavigationKey(event) {
        if (event.key !== Qt.Key_Backspace || event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        if (event.modifiers & Qt.ShiftModifier ? forward() : back())
            event.accepted = true;
    }

    function close() {
        panel = "";
        backHistory = [];
        forwardHistory = [];
    }
}
