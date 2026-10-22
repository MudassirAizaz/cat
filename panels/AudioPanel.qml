import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

PanelFrame {
    panelName: "audio"
    panelWidth: 320
    panelHeight: 190

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        RowLayout {
            Label { text: "VOLUME"; font.pixelSize: Config.scaledFontSize(11); font.letterSpacing: 1.5; Layout.fillWidth: true }
            CloseButton { panelTitle: "volume" }
        }
        Label { text: Audio.deviceName; Layout.fillWidth: true; color: Theme.muted; font.pixelSize: Config.scaledFontSize(11) }
        RowLayout {
            spacing: 10
            IconButton { iconName: Audio.icon; selected: Audio.muted; enabled: Audio.available; hint: Audio.muted ? "Unmute" : "Mute"; onClicked: Audio.toggleMute() }
            ValueSlider {
                Layout.fillWidth: true
                enabled: Audio.available
                value: Audio.volume
                Accessible.name: "Output volume"
                onMoved: Audio.setVolume(value)
            }
            Label { text: Math.round(Audio.volume * 100) + "%"; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight; font.pixelSize: Config.scaledFontSize(11) }
        }
        Label { text: Audio.muted ? "Output muted" : "Scroll the bar icon to adjust volume"; color: Theme.subtle; font.pixelSize: Config.scaledFontSize(10); Layout.fillWidth: true }
    }
}
