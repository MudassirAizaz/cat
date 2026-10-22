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
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    function setVolume(value) {
        if (!audio) return;
        audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute() {
        if (audio) audio.muted = !audio.muted;
    }
}
