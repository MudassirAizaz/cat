pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    // Choose catppuccin-mocha, everforest, gruvbox, or tokyo-night.
    property alias palette: savedState.palette
    property alias wallpaper: savedState.wallpaper

    FileView {
        path: Quickshell.stateDir + "/settings.json"
        blockLoading: true
        printErrors: false
        JsonAdapter {
            id: savedState
            property string palette: "everforest"
            property string wallpaper: ""
        }
        onAdapterUpdated: writeAdapter()
    }

    // Every shell colour lives here. Add a palette with the same keys.
    readonly property var palettes: ({
        "catppuccin-mocha": {
            background: "#181825", surface: "#1e1e2e", raised: "#313244",
            foreground: "#cdd6f4", muted: "#a6adc8", subtle: "#6c7086",
            border: "#45475a", accent: "#89b4fa", onAccent: "#1e1e2e",
            danger: "#f38ba8", warning: "#f9e2af"
        },
        "everforest": {
            background: "#1e2326", surface: "#272e33", raised: "#343f44",
            foreground: "#d3c6aa", muted: "#9da9a0", subtle: "#7a8478",
            border: "#414b50", accent: "#a7c080", onAccent: "#1e2326",
            danger: "#e67e80", warning: "#dbbc7f"
        },
        "gruvbox": {
            background: "#1d2021", surface: "#282828", raised: "#3c3836",
            foreground: "#ebdbb2", muted: "#bdae93", subtle: "#928374",
            border: "#504945", accent: "#b8bb26", onAccent: "#1d2021",
            danger: "#fb4934", warning: "#fabd2f"
        },
        "tokyo-night": {
            background: "#16161e", surface: "#1a1b26", raised: "#24283b",
            foreground: "#c0caf5", muted: "#a9b1d6", subtle: "#787c99",
            border: "#3b4261", accent: "#7aa2f7", onAccent: "#16161e",
            danger: "#f7768e", warning: "#e0af68"
        }
    })
    readonly property var current: palettes[palette] || palettes.everforest
    readonly property color background: current.background
    readonly property color surface: current.surface
    readonly property color raised: current.raised
    readonly property color foreground: current.foreground
    readonly property color muted: current.muted
    readonly property color subtle: current.subtle
    readonly property color border: current.border
    readonly property color accent: current.accent
    readonly property color onAccent: current.onAccent
    readonly property color danger: current.danger
    readonly property color warning: current.warning
    readonly property color clear: Qt.rgba(0, 0, 0, 0)
}
