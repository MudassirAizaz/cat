pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import ".."
import "../components"
import "../services"

PanelFrame {
    id: root
    panelName: "power"
    panelWidth: 340
    panelHeight: 380
    readonly property var battery: UPower.displayDevice
    readonly property bool charging: battery.state === UPowerDeviceState.Charging
    readonly property string batteryDetail: {
        if (!battery.isPresent) return "Connected to external power";
        if (battery.state === UPowerDeviceState.FullyCharged) return "Fully charged";
        const seconds = charging ? battery.timeToFull : battery.timeToEmpty;
        if (seconds <= 0) return charging ? "Charging" : UPower.onBattery ? "On battery" : "Plugged in";
        const minutes = Math.round(seconds / 60);
        const time = (minutes >= 60 ? Math.floor(minutes / 60) + "h " : "") + (minutes % 60) + "m";
        return time + (charging ? " until full" : " remaining");
    }
    onOpened: PowerState.refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        RowLayout {
            Label { text: "POWER"; font.pixelSize: Config.scaledFontSize(11); font.letterSpacing: 1.5; Layout.fillWidth: true }
            CloseButton { panelTitle: "power" }
        }
        RowLayout {
            spacing: 12
            Icon { name: root.charging ? "battery-charging" : root.battery.isPresent ? "battery" : "power"; level: root.battery.percentage; color: Theme.accent; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Label { text: root.battery.isPresent ? Math.round(root.battery.percentage * 100) + "%" : "AC power"; font.pixelSize: Config.scaledFontSize(20) }
                Label { text: root.batteryDetail; color: Theme.muted; font.pixelSize: Config.scaledFontSize(11); Layout.fillWidth: true }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        Label { text: "POWER PROFILE"; color: Theme.subtle; font.pixelSize: Config.scaledFontSize(10); font.letterSpacing: 1 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: ["power-saver", "balanced", "performance"]
                ActionButton {
                    id: profile
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 42
                    enabled: PowerState.profiles.indexOf(modelData) !== -1 && !PowerState.busy
                    selected: PowerState.active === modelData
                    hint: PowerState.title(modelData)
                    contentItem: RowLayout {
                        spacing: 10
                        Icon { Layout.leftMargin: 12; name: profile.modelData === "power-saver" ? "leaf" : profile.modelData; color: profile.selected ? Theme.onAccent : Theme.muted }
                        Label { text: PowerState.title(profile.modelData); color: profile.selected ? Theme.onAccent : Theme.foreground; Layout.fillWidth: true; font.pixelSize: Config.scaledFontSize(12) }
                        Icon { visible: profile.selected; name: "check"; color: Theme.onAccent; Layout.rightMargin: 12; implicitWidth: 15; implicitHeight: 15 }
                        opacity: profile.enabled || profile.selected ? 1 : 0.35
                    }
                    onClicked: PowerState.select(modelData)
                }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: PowerState.error || (PowerState.busy ? "Updating profiles…" : "Unavailable profiles are dimmed.")
            color: PowerState.error ? Theme.danger : Theme.subtle
            font.pixelSize: Config.scaledFontSize(10)
            wrapMode: Text.WordWrap
        }
    }
}
