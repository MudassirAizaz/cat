pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

PanelFrame {
    id: root
    panelName: "network"
    panelWidth: 380
    panelHeight: 490
    onOpened: {
        password.text = "";
        NetworkState.cancelSelection();
    }
    onVisibleChanged: {
        if (!visible)
            password.text = "";
    }

    Connections {
        target: NetworkState
        function onPasswordRequiredChanged() {
            password.text = "";
            if (NetworkState.passwordRequired && root.visible)
                Qt.callLater(() => password.forceActiveFocus());
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        RowLayout {
            Label {
                text: "NETWORK"
                font.pixelSize: Config.scaledFontSize(11)
                font.letterSpacing: 1.5
                Layout.fillWidth: true
            }
            ActionButton {
                text: NetworkState.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                selected: NetworkState.wifiEnabled
                enabled: NetworkState.available && NetworkState.hardwareEnabled
                onClicked: NetworkState.toggleWifi()
            }
            CloseButton {
                panelTitle: "network"
            }
        }
        Label {
            text: NetworkState.limited ? NetworkState.status + " · limited internet" : NetworkState.status
            Layout.fillWidth: true
            color: NetworkState.limited ? Theme.warning : Theme.muted
            font.pixelSize: Config.scaledFontSize(11)
        }
        Label {
            text: NetworkState.error
            visible: text.length > 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.danger
            font.pixelSize: Config.scaledFontSize(11)
        }

        ColumnLayout {
            visible: NetworkState.passwordRequired && !!NetworkState.selected
            Layout.fillWidth: true
            spacing: 8
            Label {
                text: NetworkState.selected?.name || ""
                Layout.fillWidth: true
                color: Theme.accent
                font.pixelSize: Config.scaledFontSize(12)
            }
            SearchBox {
                id: password
                Layout.fillWidth: true
                implicitHeight: 38
                placeholderText: "Wi-Fi password"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                onAccepted: {
                    if (!text)
                        return;
                    NetworkState.authenticate(text);
                    text = "";
                }
            }
            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                ActionButton {
                    text: "Cancel"
                    onClicked: NetworkState.cancelSelection()
                }
                ActionButton {
                    text: "Connect"
                    selected: true
                    enabled: password.text.length > 0 && !NetworkState.busy
                    onClicked: {
                        NetworkState.authenticate(password.text);
                        password.text = "";
                    }
                }
            }
        }
        Label {
            visible: NetworkState.needsSetup(NetworkState.selected)
            text: "This network needs additional setup. Configure it in Network settings below, then select it here."
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.warning
            font.pixelSize: Config.scaledFontSize(11)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 4
                model: NetworkState.wifiEnabled ? NetworkState.networks : []
                boundsBehavior: Flickable.StopAtBounds
                delegate: ActionButton {
                    id: networkRow
                    required property var modelData
                    width: list.width
                    implicitHeight: 54
                    enabled: !NetworkState.busy
                    hint: modelData.name
                    contentItem: RowLayout {
                        spacing: 10
                        Icon {
                            Layout.leftMargin: 8
                            name: "wifi"
                            color: networkRow.modelData.connected ? Theme.accent : Theme.muted
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label {
                                text: networkRow.modelData.name
                                Layout.fillWidth: true
                                font.pixelSize: Config.scaledFontSize(12)
                                color: networkRow.modelData.connected ? Theme.accent : Theme.foreground
                            }
                            Label {
                                text: NetworkState.pending === networkRow.modelData ? "Connecting…" : networkRow.modelData.connected ? "Connected · " + Math.round(networkRow.modelData.signalStrength * 100) + "%" : (networkRow.modelData.known ? "Saved · " : "") + Math.round(networkRow.modelData.signalStrength * 100) + "% signal"
                                Layout.fillWidth: true
                                font.pixelSize: Config.scaledFontSize(10)
                                color: Theme.subtle
                            }
                        }
                        Icon {
                            Layout.rightMargin: 8
                            name: networkRow.modelData.connected ? "check" : "lock"
                            visible: networkRow.modelData.connected || NetworkState.supportsPassword(networkRow.modelData) || NetworkState.needsSetup(networkRow.modelData)
                            color: networkRow.modelData.connected ? Theme.accent : Theme.subtle
                            implicitWidth: 14
                            implicitHeight: 14
                        }
                    }
                    background: Rectangle {
                        radius: Config.radius
                        color: networkRow.hovered || networkRow.modelData.connected ? Theme.raised : Theme.clear
                    }
                    onClicked: NetworkState.choose(modelData)
                }
            }
            EmptyState {
                anchors.centerIn: parent
                width: parent.width - 20
                visible: list.count === 0
                title: !NetworkState.available ? "No Wi-Fi adapter" : !NetworkState.hardwareEnabled ? "Wi-Fi is blocked" : !NetworkState.wifiEnabled ? "Wi-Fi is off" : "Looking for networks"
                subtitle: !NetworkState.available ? "Check that NetworkManager is running." : !NetworkState.hardwareEnabled ? "Check your wireless hardware switch." : !NetworkState.wifiEnabled ? "Turn Wi-Fi on to see nearby networks." : "Nearby networks appear here automatically."
            }
        }
        RowLayout {
            ActionButton {
                text: "Network settings"
                onClicked: Quickshell.execDetached(["nm-connection-editor"])
            }
            Item {
                Layout.fillWidth: true
            }
            ActionButton {
                text: "Disconnect"
                visible: !!NetworkState.connectedNetwork
                enabled: !NetworkState.busy
                onClicked: NetworkState.connectedNetwork?.disconnect()
            }
        }
    }
}
