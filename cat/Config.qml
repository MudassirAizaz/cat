pragma Singleton
import QtQuick

QtObject {
    property string fontFamily: "JetBrains Mono"
    property int fontSize: 14
    // Scale headings and smaller labels with the main font size.
    function scaledFontSize(pixels) {
        return Math.max(1, Math.round(pixels * fontSize / 13));
    }
    property int barHeight: 30
    property int gap: 10
    property int radius: 6
    property int workspaceCount: 5
    property int notificationLimit: 100
    property int toastDuration: 6000
    // The terminal and its execute flag; used for Terminal=true desktop entries.
    property var terminalCommand: ["ghostty", "-e"]
}
