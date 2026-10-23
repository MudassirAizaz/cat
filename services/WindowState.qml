pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    readonly property var activeWindow: Hyprland.activeToplevel
    property var inspectedWindow: null
    readonly property bool inspectionAvailable: !!inspectedWindow
        && Hyprland.toplevels.values.includes(inspectedWindow)

    onActiveWindowChanged: {
        if (activeWindow)
            capture();
    }

    function capture() {
        // Keep the last application when a shell surface temporarily takes focus.
        inspectedWindow = activeWindow || inspectedWindow;
        Hyprland.refreshToplevels();
    }

    function applicationFor(window) {
        if (!window) return { name: "Desktop", icon: "", id: "" };
        const data = window.lastIpcObject || {};
        const ids = [window.wayland?.appId, data.class, data.initialClass].filter(Boolean);
        let entry = null;
        for (const id of ids) {
            entry = DesktopEntries.heuristicLookup(id);
            if (entry) break;
        }
        return {
            name: entry?.name || ids[0] || "Unknown application",
            icon: entry?.icon || "",
            id: ids[0] || ""
        };
    }

}
