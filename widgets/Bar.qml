pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import ".."
import "../components"
import "../services"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Config.barHeight
    exclusiveZone: Config.barHeight
    color: Theme.background
    WlrLayershell.namespace: "cat-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var battery: UPower.displayDevice
    readonly property bool charging: battery.state === UPowerDeviceState.Charging
    readonly property var shownWindow: ShellState.panel === "window"
        ? WindowState.inspectedWindow : WindowState.activeWindow
    readonly property var application: WindowState.applicationFor(shownWindow)

    function openPanel(name, button) {
        const point = button.mapToItem(root.contentItem, button.width / 2, button.height);
        ShellState.toggle(name, root.screen, point.x);
    }

    function isOpen(name) {
        return ShellState.panel === name && ShellState.panelScreen === root.screen;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        id: surface
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: ShellState.close()
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        // Every control shares a 28px box on the same integer-aligned baseline.
        Row {
            id: leftGroup
            x: 8
            y: Math.round((surface.height - height) / 2)
            height: 28
            spacing: 8
            IconButton {
                id: menuButton
                iconName: "menu"
                hint: "Menu"
                focusPolicy: Qt.NoFocus
                selected: root.isOpen("menu")
                onClicked: root.openPanel("menu", menuButton)
            }
            WorkspaceSwitcher {
                monitor: root.monitor
            }
            ActionButton {
                id: windowButton
                objectName: "windowButton"
                visible: root.width > 1100
                width: 200
                height: 28
                focusPolicy: Qt.NoFocus
                text: root.application.name
                hint: "Window details"
                enabled: !!root.shownWindow || root.isOpen("window")
                selected: root.isOpen("window")
                contentItem: Row {
                    spacing: 8
                    leftPadding: 8
                    rightPadding: 8
                    ApplicationIcon {
                        objectName: "windowButtonIcon"
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: root.application.icon
                        fallbackColor: windowButton.selected ? Theme.onAccent : Theme.muted
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, windowButton.width - 42)
                        height: 28
                        text: windowButton.text
                        color: windowButton.selected ? Theme.onAccent : Theme.muted
                        font.pixelSize: Config.scaledFontSize(11)
                    }
                }
                onClicked: {
                    if (!root.isOpen("window")) WindowState.capture();
                    root.openPanel("window", windowButton);
                }
            }
        }

        ActionButton {
            id: clockButton
            objectName: "calendarButton"
            x: Math.round((surface.width - width) / 2)
            height: 28
            y: Math.round((surface.height - height) / 2)
            visible: leftGroup.x + leftGroup.width + 16 < x && x + width + 16 < rightGroup.x
            text: Qt.formatDateTime(clock.date, "ddd, dd MMM  ·  HH:mm")
            hint: "Date and calendar"
            focusPolicy: Qt.NoFocus
            selected: root.isOpen("calendar")
            contentItem: Label {
                text: clockButton.text
                color: clockButton.selected ? Theme.onAccent : Theme.foreground
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Config.scaledFontSize(11)
            }
            onClicked: root.openPanel("calendar", clockButton)
        }

        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: 8
            y: Math.round((surface.height - height) / 2)
            height: 28
            spacing: 4
            Row {
                visible: root.width > 750
                spacing: 4
                height: 28
                Repeater {
                    model: SystemTray.items
                    Item {
                        id: trayItem
                        required property var modelData
                        width: 26
                        height: 28
                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: trayItem.modelData.icon
                            sourceSize.width: 16
                            sourceSize.height: 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: event => {
                                ShellState.close();
                                if (event.button === Qt.MiddleButton)
                                    trayItem.modelData.secondaryActivate();
                                else if (event.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                    const point = trayItem.mapToItem(root.contentItem, 0, trayItem.height);
                                    trayItem.modelData.display(root, point.x, point.y);
                                } else
                                    trayItem.modelData.activate();
                            }
                            onWheel: event => trayItem.modelData.scroll(event.angleDelta.y, false)
                        }
                    }
                }
            }
            IconButton {
                id: networkButton
                iconName: NetworkState.icon
                iconColor: selected ? Theme.onAccent : NetworkState.limited ? Theme.warning : Theme.foreground
                hint: NetworkState.status
                focusPolicy: Qt.NoFocus
                selected: root.isOpen("network")
                onClicked: root.openPanel("network", networkButton)
            }
            IconButton {
                id: audioButton
                iconName: Audio.icon
                hint: Audio.muted ? "Volume muted" : "Volume " + Math.round(Audio.volume * 100) + "%"

                focusPolicy: Qt.NoFocus
                selected: root.isOpen("audio")
                onClicked: root.openPanel("audio", audioButton)
                WheelHandler {
                    onWheel: event => {
                        Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05));
                        event.accepted = true;
                    }
                }
            }
            IconButton {
                id: powerButton
                iconName: root.charging ? "battery-charging" : root.battery.isPresent ? "battery" : "power"
                level: root.battery.percentage
                iconColor: selected ? Theme.onAccent : root.battery.isPresent && UPower.onBattery && level < 0.2 ? Theme.warning : Theme.foreground
                hint: root.battery.isPresent ? "Battery " + Math.round(level * 100) + "%" : "Power profiles"

                focusPolicy: Qt.NoFocus
                selected: root.isOpen("power")
                onClicked: root.openPanel("power", powerButton)
            }
        }
    }
}
