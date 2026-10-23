"""Exercise control services offscreen with isolated network/power backends."""
from pathlib import Path
import shutil
import tempfile
import unittest

from support import ROOT, assert_qml_passes, qml_environment


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is required")
class ControlTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "services").mkdir()
        (self.root / "runtime").mkdir(mode=0o700)
        (self.root / "ShellState.qml").write_text(
            'pragma Singleton\nimport QtQuick\nQtObject { property string panel: "" }\n'
        )
        (self.root / "qmldir").write_text("singleton ShellState 1.0 ShellState.qml\n")
        self.env = qml_environment(self.root)

    def run_qml(self, body, marker):
        (self.root / "shell.qml").write_text(body)
        assert_qml_passes(self, self.root, marker, self.env)

    def test_wifi_password_retry_saved_open_and_enterprise_networks(self):
        fake = self.root / "fake"
        fake.mkdir()
        enums = {
            "DeviceType": "Wifi, Wired",
            "WifiSecurityType": "Open, Owe, WpaPsk, Wpa2Psk, Sae, Wpa2Eap",
            "ConnectionState": "Disconnected, Connecting, Connected",
            "ConnectionFailReason": "NoSecrets, WifiAuthTimeout",
            "NetworkConnectivity": "Unknown, Full, Limited, Portal",
        }
        for name, values in enums.items():
            (fake / f"{name}.qml").write_text(
                f"pragma Singleton\nimport QtQuick\nQtObject {{ enum Value {{ {values} }} }}\n"
            )
        (fake / "Networking.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var devices: ({ values: [] })
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property int connectivity: NetworkConnectivity.Full
}
''')
        (fake / "qmldir").write_text("\n".join(
            f"singleton {name} 1.0 {name}.qml" for name in [*enums, "Networking"]
        ))
        service = (ROOT / "services/NetworkState.qml").read_text()
        (self.root / "services/NetworkState.qml").write_text(
            service.replace("import Quickshell.Networking", 'import "../fake"')
        )
        (self.root / "services/qmldir").write_text("singleton NetworkState 1.0 NetworkState.qml\n")
        self.run_qml('''import QtQuick
import Quickshell
import "fake"
import "services"
ShellRoot {
    id: root
    property QtObject network: QtObject {
        property string name: "Test network"
        property int security: WifiSecurityType.Wpa2Psk
        property bool known: false
        property bool connected: false
        property int state: ConnectionState.Disconnected
        property real signalStrength: 0.8
        property int connects: 0
        property int authentications: 0
        property string lastSecret: ""
        property int disconnects: 0
        signal connectionFailed(int reason)
        function connect() { connects++; state = ConnectionState.Connecting; }
        function connectWithPsk(secret) { lastSecret = secret; authentications++; state = ConnectionState.Connecting; }
        function disconnect() {
            disconnects++;
            connected = false;
            state = ConnectionState.Disconnected;
            connectionFailed(ConnectionFailReason.WifiAuthTimeout);
        }
    }
    property QtObject radio: QtObject {
        property int type: DeviceType.Wifi
        property bool scannerEnabled: false
        property var networks: ({ values: [root.network] })
    }
    Component.onCompleted: {
        Networking.devices = { values: [radio] };
        const networks = NetworkState.networks;
        ShellState.panel = "network";
    }
    function check(value, message) { if (!value) throw new Error(message); }
    function connected() { network.connected = true; network.state = ConnectionState.Connected; }
    Timer {
        interval: 200
        running: true
        onTriggered: {
            try {
                root.check(root.radio.scannerEnabled, "scan starts with popup");
                NetworkState.choose(root.network);
                root.check(NetworkState.passwordRequired && !NetworkState.busy, "new WPA network prompts");
                NetworkState.authenticate("test-passphrase");
                root.check(NetworkState.busy && root.network.authentications === 1, "PSK uses direct backend method");
                root.check(root.network.lastSecret === "test-passphrase", "password is forwarded intact");
                root.network.connectionFailed(ConnectionFailReason.NoSecrets);
                root.check(NetworkState.passwordRequired && !NetworkState.busy && NetworkState.error.length > 0, "wrong password permits retry");
                NetworkState.authenticate("test-passphrase-again");
                root.connected();
                root.check(!NetworkState.busy && !NetworkState.passwordRequired && !NetworkState.error, "success clears prompt");
                root.network.disconnect();
                root.network.known = true;
                NetworkState.choose(root.network);
                root.check(root.network.connects === 1 && !NetworkState.passwordRequired, "saved credentials reused");
                root.connected();
                root.network.disconnect();
                root.network.known = false;
                root.network.security = WifiSecurityType.Open;
                NetworkState.choose(root.network);
                root.check(root.network.connects === 2 && !NetworkState.passwordRequired, "open network connects without secret");
                root.connected();
                root.network.disconnect();
                root.network.security = WifiSecurityType.Wpa2Eap;
                NetworkState.choose(root.network);
                root.check(NetworkState.needsSetup(root.network) && !NetworkState.busy, "unsaved enterprise network requires setup");
                NetworkState.toggleWifi();
                root.check(!Networking.wifiEnabled && !NetworkState.selected, "radio toggle clears prompt");
                Networking.wifiEnabled = true;
                root.network.security = WifiSecurityType.Open;
                NetworkState.choose(root.network);
                const previousDisconnects = root.network.disconnects;
                NetworkState.handleTimeout();
                root.check(!NetworkState.busy && root.network.disconnects === previousDisconnects + 1, "timeout cancels backend request");
                root.check(NetworkState.error.includes("timed out"), "disconnect failure does not replace timeout error");
                NetworkState.choose(root.network);
                root.check(NetworkState.busy && !NetworkState.error, "timeout allows a fresh retry");
                NetworkState.toggleWifi();
                root.check(!NetworkState.busy && !NetworkState.error, "radio toggle cancels pending connection");
                console.log("NETWORK_STATE_PASS");
            } catch (error) { console.log("TEST FAILURE", error.message); }
            Qt.quit();
        }
    }
}
''', "NETWORK_STATE_PASS")

    def test_power_profile_success_and_failure(self):
        shutil.copy(ROOT / "services/PowerState.qml", self.root / "services/PowerState.qml")
        (self.root / "services/qmldir").write_text("singleton PowerState 1.0 PowerState.qml\n")
        binary = self.root / "powerprofilesctl"
        binary.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
state = pathlib.Path(os.environ["CAT_TEST_POWER"])
if sys.argv[1] == "list":
    if state.with_suffix(".failed").exists():
        print("* balanced:")
        sys.exit(1)
    active = state.read_text() if state.exists() else "balanced"
    for name in ("performance", "balanced", "power-saver"):
        print(("* " if name == active else "  ") + name + ":")
        print("    CpuDriver: test")
elif sys.argv[1] == "set":
    if sys.argv[2] == "power-saver":
        state.with_suffix(".failed").write_text("failed")
        sys.exit(1)
    state.write_text(sys.argv[2])
''')
        binary.chmod(0o755)
        self.env.update(
            PATH=f"{self.root}:{self.env['PATH']}",
            CAT_TEST_POWER=str(self.root / "profile"),
        )
        self.run_qml('''import QtQuick
import Quickshell
import "services"
ShellRoot {
    Component.onCompleted: PowerState.refresh()
    Timer {
        property int step: 0
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (PowerState.busy || !PowerState.loaded) return;
            try {
                if (step === 0) {
                    if (PowerState.profiles.length !== 3 || PowerState.active !== "balanced") throw new Error("parse profiles");
                    PowerState.select("performance");
                    step++;
                } else if (step === 1) {
                    if (PowerState.active !== "performance") throw new Error("profile change confirmed");
                    PowerState.select("power-saver");
                    step++;
                } else if (step === 2) {
                    if (!PowerState.error || PowerState.active !== "performance") throw new Error("failure preserves actual profile");
                    PowerState.refresh();
                    step++;
                } else {
                    if (!PowerState.error || PowerState.active !== "performance" || PowerState.profiles.length !== 3)
                        throw new Error("failed refresh preserves previous profiles");
                    console.log("POWER_STATE_PASS");
                    Qt.quit();
                }
            } catch (error) { console.log("TEST FAILURE", error.message); Qt.quit(); }
        }
    }
}
''', "POWER_STATE_PASS")


if __name__ == "__main__":
    unittest.main()
