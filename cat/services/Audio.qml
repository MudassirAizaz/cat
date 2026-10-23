pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio || null
    readonly property bool available: !!audio
    readonly property real volume: audio?.volume || 0
    readonly property bool muted: audio?.muted || false
    readonly property string icon: !available || muted || volume === 0 ? "volume-muted" : volume < 0.5 ? "volume-low" : "volume"
    readonly property string deviceName: sink?.description || sink?.name || "No audio output"
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && node.isSink)
    readonly property var inputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && !node.isSink)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source?.audio || null
    readonly property bool microphoneAvailable: !!sourceAudio
    readonly property real microphoneVolume: sourceAudio?.volume || 0
    readonly property bool microphoneMuted: sourceAudio?.muted || false
    readonly property string microphoneIcon: !microphoneAvailable || microphoneMuted ? "microphone-muted" : "microphone"

    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => !!node)
    }

    function setVolume(value) {
        if (!audio)
            return;
        audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute() {
        if (audio)
            audio.muted = !audio.muted;
    }

    function selectOutput(node) {
        if (outputs.includes(node))
            Pipewire.preferredDefaultAudioSink = node;
    }

    function selectInput(node) {
        if (inputs.includes(node))
            Pipewire.preferredDefaultAudioSource = node;
    }

    function setMicrophoneVolume(value) {
        if (sourceAudio)
            sourceAudio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMicrophoneMute() {
        if (sourceAudio)
            sourceAudio.muted = !sourceAudio.muted;
    }
}
