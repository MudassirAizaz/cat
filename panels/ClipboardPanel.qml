pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

PanelFrame {
    id: root
    panelName: "clipboard"
    panelWidth: 500
    panelHeight: 540
    property bool confirmClear: false
    readonly property var results: Clipboard.entries.filter(entry => entry.preview.toLowerCase().includes(search.text.toLowerCase()))

    function move(delta) {
        if (!list.count) return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    onOpened: { search.text = ""; confirmClear = false; Clipboard.refresh(); search.forceActiveFocus(); }
    onResultsChanged: list.currentIndex = Math.min(Math.max(0, list.currentIndex), results.length - 1)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14
        RowLayout {
            Label { text: "CLIPBOARD"; font.pixelSize: Config.scaledFontSize(11); font.letterSpacing: 2; Layout.fillWidth: true }
            ActionButton {
                text: root.confirmClear ? "confirm clear" : "clear all"
                destructive: root.confirmClear
                enabled: Clipboard.entries.length > 0 && !Clipboard.busy
                onClicked: {
                    if (root.confirmClear) { Clipboard.run("wipe"); root.confirmClear = false; }
                    else root.confirmClear = true;
                }
            }
            CloseButton { panelTitle: "clipboard" }
        }
        SearchBox {
            id: search
            Layout.fillWidth: true
            placeholderText: "Find something you copied…"
            onAccepted: { if (root.results[list.currentIndex]) Clipboard.run("copy", root.results[list.currentIndex].id); }
            Keys.onDownPressed: root.move(1)
            Keys.onUpPressed: root.move(-1)
            Keys.onPressed: event => {
                if (search.text.length === 0) ShellState.handleNavigationKey(event);
                if (event.key === Qt.Key_Delete && event.modifiers & Qt.ControlModifier && root.results[list.currentIndex]) {
                    Clipboard.run("delete", root.results[list.currentIndex].id);
                    event.accepted = true;
                }
            }
        }
        Label { visible: Clipboard.error.length > 0; text: Clipboard.error; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.danger; font.pixelSize: Config.scaledFontSize(11) }
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 5
                model: root.results
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 64
                    color: ListView.isCurrentItem || mouse.containsMouse ? Theme.raised : Theme.background
                    radius: Config.radius
                    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Clipboard.run("copy", row.modelData.id) }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        Label { text: String(row.index + 1).padStart(2, "0"); color: row.ListView.isCurrentItem ? Theme.accent : Theme.subtle; font.pixelSize: Config.scaledFontSize(11) }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Label {
                                anchors.fill: parent
                                visible: row.modelData.imagePath.length === 0
                                text: row.modelData.preview
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                font.pixelSize: Config.scaledFontSize(12)
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: row.modelData.imagePath.length > 0
                                radius: Config.radius - 2
                                color: Theme.surface
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: row.modelData.imagePath.length > 0
                                        ? "file://" + row.modelData.imagePath.split("/").map(part => encodeURIComponent(part)).join("/") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 280
                                    sourceSize.height: 52
                                    Accessible.name: row.modelData.preview
                                }
                            }
                        }
                        ActionButton { text: "×"; hint: "Delete this entry"; destructive: true; enabled: !Clipboard.busy; onClicked: Clipboard.run("delete", row.modelData.id) }
                    }
                }
            }
            EmptyState { anchors.centerIn: parent; width: parent.width - 30; visible: list.count === 0 && !Clipboard.error; title: search.text ? "No matching entries" : "A fresh clipboard"; subtitle: search.text ? "Try a different search." : "Copy something. It will be waiting here." }
        }
        Label { text: "↵ copy   ·   ctrl+delete remove   ·   esc close"; font.pixelSize: Config.scaledFontSize(10); color: Theme.muted; Layout.fillWidth: true }
    }
}
