"""Exercise device routing and audio controls without changing desktop audio."""
from pathlib import Path
import shutil
import tempfile
import unittest

from support import ROOT, assert_qml_passes, floating_window


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class AudioTests(unittest.TestCase):
    def test_device_switching_independent_controls_and_hotplug(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ("components", "services"):
                shutil.copytree(ROOT / folder, root / folder)
            (root / "panels").mkdir()
            shutil.copy(ROOT / "panels/AudioPanel.qml", root / "panels")
            for name in ("Config.qml", "Theme.qml", "ShellState.qml", "qmldir"):
                shutil.copy(ROOT / name, root / name)
            frame = root / "components/PanelFrame.qml"
            frame.write_text(floating_window(frame.read_text()))
            service = root / "services/Audio.qml"
            service.write_text(service.read_text().replace(
                "import Quickshell.Services.Pipewire", 'import "../fake"'))
            fake = root / "fake"
            fake.mkdir()
            (fake / "qmldir").write_text(
                "singleton Pipewire 1.0 Pipewire.qml\n"
                "AudioNode 1.0 AudioNode.qml\n"
                "PwObjectTracker 1.0 PwObjectTracker.qml\n")
            (fake / "Pipewire.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var nodes: ({ values: [] })
    property var defaultAudioSink: null
    property var defaultAudioSource: null
    property var preferredDefaultAudioSink: null
    property var preferredDefaultAudioSource: null
    property var tracked: []
}
''')
            (fake / "PwObjectTracker.qml").write_text('''import QtQuick
QtObject {
    property var objects: []
    onObjectsChanged: Pipewire.tracked = objects
}
''')
            (fake / "AudioNode.qml").write_text('''import QtQuick
QtObject {
    property string name: "test-node"
    property string description: ""
    property bool isSink: false
    property bool isStream: false
    property QtObject audio: QtObject {
        property real volume: 0.5
        property bool muted: false
    }
}
''')
            (root / "shell.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import "fake"
import "services"
import "panels"
ShellRoot {
    id: root
    AudioNode { id: speaker; description: "Speakers"; isSink: true }
    AudioNode { id: headphones; description: "Headphones"; isSink: true }
    AudioNode { id: mic; description: "Built-in microphone" }
    AudioNode { id: usbMic; description: "USB microphone" }
    AudioNode { id: stream; isStream: true; isSink: true }
    AudioNode { id: capture; isStream: true }
    AudioNode { id: video; audio: null }
    AudioPanel { id: popup }
    TestEvent { id: events }
    Component.onCompleted: {
        Pipewire.nodes = { values: [speaker, headphones, mic, usbMic, stream, capture, video] };
        Pipewire.defaultAudioSink = speaker;
        Pipewire.defaultAudioSource = mic;
        ShellState.toggle("audio");
    }
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
        function option(item, node) {
            if (item.objectName === "audioDevice" && item.modelData === node) return item;
            for (const child of item.children || []) {
                const found = option(child, node);
                if (found) return found;
            }
            return null;
        }
        function click(item, position) {
            check(!!item && item.enabled && item.visible, "control is usable");
            events.mouseClick(item, item.width * (position ?? 0.5), item.height / 2,
                Qt.LeftButton, Qt.NoModifier, 0);
        }
        onTriggered: {
            try {
                const output = find(popup.contentItem, "audioOutput");
                const input = find(popup.contentItem, "audioMicrophone");
                const outputSlider = find(output, "audioVolume");
                const inputSlider = find(input, "audioVolume");
                if (step === 0) {
                    check(popup.visible && Audio.available && Audio.microphoneAvailable, "audio panel is ready");
                    check(Audio.outputs.length === 2 && Audio.inputs.length === 2, "streams and video excluded from devices");
                    check(Pipewire.tracked.includes(speaker) && Pipewire.tracked.includes(mic), "both defaults tracked");
                    click(find(output, "devicePicker"));
                } else if (step === 1) {
                    check(output.expanded && option(output, speaker).selected, "output choices show active device");
                    click(option(output, headphones));
                    check(Pipewire.preferredDefaultAudioSink === headphones, "output selection reaches PipeWire");
                    check(!output.expanded && Audio.sink === speaker, "picker closes and waits for confirmed default");
                    Pipewire.defaultAudioSink = headphones;
                } else if (step === 2) {
                    check(output.device === headphones && Audio.deviceName === "Headphones", "confirmed output displayed");
                    check(Pipewire.tracked.includes(headphones) && !Pipewire.tracked.includes(speaker), "tracker follows output");
                    click(find(input, "devicePicker"));
                } else if (step === 3) {
                    click(option(input, usbMic));
                    check(Pipewire.preferredDefaultAudioSource === usbMic, "microphone selection reaches PipeWire");
                    check(Pipewire.preferredDefaultAudioSink === headphones, "input selection preserves output");
                    Pipewire.defaultAudioSource = usbMic;
                } else if (step === 4) {
                    check(input.device === usbMic && Pipewire.tracked.includes(usbMic), "microphone follows default");
                    click(find(output, "audioMute"));
                    check(headphones.audio.muted && !usbMic.audio.muted, "output mute is independent");
                    click(find(input, "audioMute"));
                    check(usbMic.audio.muted && Audio.microphoneIcon === "microphone-muted", "microphone mute works");
                    click(find(input, "audioMute"));
                    check(!usbMic.audio.muted && headphones.audio.muted, "microphone unmute preserves output mute");
                    click(outputSlider, 0.8);
                    check(Audio.volume > 0.7 && Audio.volume < 0.9, "output slider changes output");
                    check(usbMic.audio.volume === 0.5 && speaker.audio.volume === 0.5, "other devices unchanged");
                    click(inputSlider, 0.25);
                    check(Audio.microphoneVolume > 0.15 && Audio.microphoneVolume < 0.35, "input slider changes microphone");
                    check(Audio.volume > 0.7, "input slider preserves output level");
                    Audio.setVolume(2);
                    Audio.setMicrophoneVolume(-1);
                    check(Audio.volume === 1 && Audio.microphoneVolume === 0, "levels clamp to allowed range");
                    headphones.audio.volume = 0.4;
                    usbMic.audio.volume = 0.6;
                } else if (step === 5) {
                    check(Math.abs(outputSlider.value - 0.4) < 0.01 && Math.abs(inputSlider.value - 0.6) < 0.01, "sliders follow external updates after interaction");
                    Pipewire.nodes = { values: [speaker, mic] };
                    Pipewire.defaultAudioSink = speaker;
                    Pipewire.defaultAudioSource = mic;
                } else if (step === 6) {
                    check(Audio.outputs.length === 1 && Audio.inputs.length === 1, "removed devices disappear");
                    Audio.selectOutput(headphones);
                    Audio.selectInput(usbMic);
                    Audio.selectOutput(mic);
                    Audio.selectInput(speaker);
                    check(Pipewire.preferredDefaultAudioSink === headphones && Pipewire.preferredDefaultAudioSource === usbMic, "stale and wrong-direction selections ignored");
                    check(output.device === speaker && input.device === mic, "controls follow fallback defaults");
                    Pipewire.nodes = { values: [] };
                    Pipewire.defaultAudioSink = null;
                    Pipewire.defaultAudioSource = null;
                } else if (step === 7) {
                    check(!outputSlider.enabled && !inputSlider.enabled, "missing devices disable sliders");
                    check(!find(output, "audioMute").enabled && !find(input, "audioMute").enabled, "missing devices disable mute");
                    check(!find(output, "devicePicker").enabled && !find(input, "devicePicker").enabled, "empty pickers disabled");
                    Audio.setVolume(0.8);
                    Audio.toggleMute();
                    Audio.setMicrophoneVolume(0.8);
                    Audio.toggleMicrophoneMute();
                    check(!Audio.available && !Audio.microphoneAvailable, "no-device operations are safe");
                    Pipewire.nodes = { values: [speaker, mic] };
                    Pipewire.defaultAudioSink = speaker;
                    Pipewire.defaultAudioSource = mic;
                } else if (step === 8) {
                    check(outputSlider.enabled && inputSlider.enabled, "hotplug restores controls");
                    click(find(output, "devicePicker"));
                    ShellState.close();
                    ShellState.toggle("audio");
                } else {
                    check(!output.expanded && !input.expanded, "reopening collapses pickers");
                    console.log("AUDIO_PASS");
                    Qt.quit();
                }
                step++;
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''')
            assert_qml_passes(self, root, "AUDIO_PASS")


if __name__ == "__main__":
    unittest.main()
