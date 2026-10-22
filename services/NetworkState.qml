pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking
import ".."

Scope {
    id: root
    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool available: wifiDevices.length > 0
    readonly property var networks: {
        let result = [];
        wifiDevices.forEach(device => {
            device.networks.values.forEach(network => { if (network.name) result.push(network); });
        });
        return result.sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength || a.name.localeCompare(b.name));
    }
    readonly property var connectedNetwork: networks.find(n => n.connected) || null
    readonly property bool wiredConnected: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property string icon: wiredConnected ? "ethernet" : connectedNetwork ? "wifi" : "wifi-off"
    readonly property string status: wiredConnected ? "Wired connection" : connectedNetwork?.name || (wifiEnabled ? "Not connected" : "Wi-Fi off")
    readonly property bool limited: Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.Portal
    property var selected: null
    property var pending: null
    property bool passwordRequired: false
    property string error: ""
    readonly property bool busy: pending !== null

    function supportsPassword(network) {
        return network && [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].indexOf(network.security) !== -1;
    }

    function needsSetup(network) {
        return network && !network.known && !supportsPassword(network)
            && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    function choose(network) {
        if (busy || !network || network.connected) return;
        error = "";
        selected = network;
        passwordRequired = supportsPassword(network) && !network.known;
        if (passwordRequired || needsSetup(network)) return;
        pending = network;
        timeout.restart();
        network.connect();
    }

    function authenticate(password) {
        if (busy || !selected || !supportsPassword(selected) || !password) return;
        error = "";
        pending = selected;
        passwordRequired = false;
        timeout.restart();
        // The secret goes directly to NetworkManager, never into a command line.
        pending.connectWithPsk(password);
    }

    function cancelSelection() {
        selected = null;
        passwordRequired = false;
        error = "";
    }

    function toggleWifi() {
        if (!hardwareEnabled) return;
        if (pending) pending.disconnect();
        pending = null;
        timeout.stop();
        cancelSelection();
        Networking.wifiEnabled = !wifiEnabled;
    }

    Variants {
        model: root.wifiDevices
        QtObject {
            id: deviceScanner
            required property var modelData
            property Binding scanner: Binding {
                target: deviceScanner.modelData
                property: "scannerEnabled"
                value: ShellState.panel === "network" && root.wifiEnabled
            }
        }
    }

    Connections {
        target: root.pending
        function onStateChanged() {
            if (root.pending?.state !== ConnectionState.Connected) return;
            root.pending = null;
            root.cancelSelection();
            timeout.stop();
        }
        function onConnectionFailed(reason) {
            const network = root.pending;
            root.pending = null;
            timeout.stop();
            root.selected = network;
            if (reason === ConnectionFailReason.NoSecrets && root.supportsPassword(network)) {
                root.passwordRequired = true;
                root.error = "A password is needed, or the saved password is incorrect.";
            } else {
                root.error = "Could not connect. Check the network and try again.";
            }
        }
    }

    Timer {
        id: timeout
        interval: 45000
        onTriggered: {
            if (root.pending?.connected) root.cancelSelection();
            else root.error = "The connection timed out. Try again or check network settings.";
            root.pending = null;
        }
    }
}
