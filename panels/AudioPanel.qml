import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

PanelFrame {
    panelName: "audio"
    panelWidth: 360
    panelHeight: content.implicitHeight + 36
    onOpened: {
        output.expanded = false;
        microphone.expanded = false;
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 18
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: content
            width: parent.width
            spacing: 14
            RowLayout {
                Label {
                    text: "AUDIO"
                    font.pixelSize: Config.scaledFontSize(11)
                    font.letterSpacing: 1.5
                    Layout.fillWidth: true
                }
                CloseButton { panelTitle: "audio" }
            }
            AudioDeviceControl {
                id: output
                objectName: "audioOutput"
                Layout.fillWidth: true
                title: "Output"
                devices: Audio.outputs
                device: Audio.sink
                available: Audio.available
                volume: Audio.volume
                muted: Audio.muted
                iconName: Audio.icon
                onDeviceSelected: node => Audio.selectOutput(node)
                onVolumeSet: value => Audio.setVolume(value)
                onMuteClicked: Audio.toggleMute()
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }
            AudioDeviceControl {
                id: microphone
                objectName: "audioMicrophone"
                Layout.fillWidth: true
                title: "Microphone"
                devices: Audio.inputs
                device: Audio.source
                available: Audio.microphoneAvailable
                volume: Audio.microphoneVolume
                muted: Audio.microphoneMuted
                iconName: Audio.microphoneIcon
                onDeviceSelected: node => Audio.selectInput(node)
                onVolumeSet: value => Audio.setMicrophoneVolume(value)
                onMuteClicked: Audio.toggleMicrophoneMute()
            }
        }
    }
}
