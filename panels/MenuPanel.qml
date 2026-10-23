pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"

PanelFrame {
    id: root
    panelName: "menu"
    centered: true
    panelWidth: 440
    panelHeight: 430
    property int currentIndex: 0

    function openPanel(name) {
        ShellState.navigate(name);
    }
    function focusEntry(index) {
        if (!entries.count) return;
        currentIndex = (index + entries.count) % entries.count;
        entries.itemAt(currentIndex)?.forceActiveFocus(Qt.TabFocusReason);
    }
    onOpened: focusEntry(currentIndex)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "MENU"
                font.pixelSize: Config.scaledFontSize(11)
                font.letterSpacing: 2
                Layout.fillWidth: true
            }
            CloseButton {
                panelTitle: "menu"
            }
        }
        Repeater {
            id: entries
            model: [
                {
                    title: "Theme",
                    detail: Theme.palette.replace(/-/g, " "),
                    icon: "theme",
                    panel: "theme"
                },
                {
                    title: "Wallpaper",
                    detail: "Choose a background",
                    icon: "wallpaper",
                    panel: "wallpaper"
                },
                {
                    title: "Apps",
                    detail: "Find and launch an application",
                    icon: "apps",
                    panel: "launcher"
                },
                {
                    title: "Clipboard",
                    detail: "Recent copies",
                    icon: "clipboard",
                    panel: "clipboard"
                },
                {
                    title: "Notification history",
                    detail: "Recent notifications",
                    icon: "history",
                    panel: "notifications"
                },
                {
                    title: "Power",
                    detail: "Lock, sleep, or end your session",
                    icon: "power",
                    panel: "session"
                }
            ]
            MenuEntry {
                id: menuRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                title: modelData.title
                detail: modelData.detail
                iconName: modelData.icon
                onActiveFocusChanged: {
                    if (activeFocus)
                        root.currentIndex = index;
                }
                onMoveRequested: delta => root.focusEntry(index + delta)
                onClicked: {
                    root.currentIndex = index;
                    root.openPanel(modelData.panel);
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
