pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    required property string title
    required property var devices
    required property var device
    required property bool available
    required property real volume
    required property bool muted
    required property string iconName
    property bool expanded: false
    signal deviceSelected(var node)
    signal volumeSet(real value)
    signal muteClicked
    spacing: 8

    Label {
        text: root.title.toUpperCase()
        color: Theme.subtle
        font.pixelSize: Config.scaledFontSize(10)
        font.letterSpacing: 1.2
    }
    ActionButton {
        objectName: "devicePicker"
        Layout.fillWidth: true
        enabled: root.devices.length > 0
        Accessible.name: "Select " + root.title.toLowerCase() + " device"
        onClicked: root.expanded = !root.expanded
        contentItem: RowLayout {
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: root.device?.description || root.device?.name || "No device available"
                color: Theme.muted
                font.pixelSize: Config.scaledFontSize(11)
            }
            Icon {
                name: "chevron-right"
                rotation: root.expanded ? -90 : 90
                color: Theme.subtle
                implicitWidth: 14
                implicitHeight: 14
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.expanded && root.devices.length > 0
        spacing: 2
        Repeater {
            model: root.devices
            ActionButton {
                id: option
                required property var modelData
                objectName: "audioDevice"
                Layout.fillWidth: true
                selected: modelData === root.device
                text: modelData.description || modelData.name
                onClicked: {
                    root.deviceSelected(modelData);
                    root.expanded = false;
                }
                contentItem: Label {
                    text: option.text
                    color: option.selected ? Theme.onAccent : Theme.foreground
                    font.pixelSize: Config.scaledFontSize(11)
                    leftPadding: 8
                    rightPadding: 8
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        IconButton {
            objectName: "audioMute"
            iconName: root.iconName
            selected: root.muted
            enabled: root.available
            hint: (root.muted ? "Unmute " : "Mute ") + root.title.toLowerCase()
            onClicked: root.muteClicked()
        }
        ValueSlider {
            objectName: "audioVolume"
            Layout.fillWidth: true
            enabled: root.available
            value: root.volume
            Accessible.name: root.title + " volume"
            onMoved: root.volumeSet(value)
        }
        Label {
            text: Math.round(root.volume * 100) + "%"
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Config.scaledFontSize(11)
        }
    }
}
