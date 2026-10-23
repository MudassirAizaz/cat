import QtQuick
import QtQuick.Templates as T
import Quickshell
import ".."

T.Button {
    id: root
    property bool selected: false
    property bool destructive: false
    property string hint: ""
    implicitHeight: 28
    implicitWidth: Math.max(28, label.implicitWidth + 20)
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    Accessible.name: hint || text
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    PopupWindow {
        id: hintWindow
        property bool ready: false
        readonly property bool requested: root.hovered && root.enabled && !root.down && root.hint.length > 0 && ShellState.panel === ""
        visible: requested && ready
        onRequestedChanged: {
            ready = false;
            if (requested)
                hintDelay.restart();
            else
                hintDelay.stop();
        }
        // A hint must never become a pointer target or take keyboard focus.
        grabFocus: false
        mask: Region {}
        anchor.item: root
        anchor.rect.x: Math.round((root.width - hintWindow.implicitWidth) / 2)
        anchor.rect.y: root.height + 6
        implicitWidth: hintLabel.implicitWidth + 16
        implicitHeight: hintLabel.implicitHeight + 12
        color: Theme.clear

        Timer {
            id: hintDelay
            interval: 650
            onTriggered: hintWindow.ready = true
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            border.color: Theme.border
            radius: Config.radius
            Label {
                id: hintLabel
                anchors.centerIn: parent
                text: root.hint
                font.pixelSize: Config.scaledFontSize(11)
            }
        }
    }

    contentItem: Label {
        id: label
        text: root.text
        color: root.selected ? Theme.onAccent : root.destructive ? Theme.danger : Theme.foreground
        horizontalAlignment: Text.AlignHCenter
        opacity: root.enabled ? 1 : 0.4
    }
    background: Rectangle {
        color: root.selected ? Theme.accent : root.hovered || root.down ? Theme.raised : Theme.clear
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent
        radius: Config.radius - 2
    }
}
