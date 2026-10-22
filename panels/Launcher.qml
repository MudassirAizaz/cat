pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"

PanelFrame {
    id: root
    panelName: "launcher"
    centered: true
    panelWidth: 580
    panelHeight: 510

    readonly property var results: {
        const query = search.text.trim().toLowerCase();
        const terms = query.split(/\s+/).filter(Boolean);
        return DesktopEntries.applications.values.filter(app => {
            const haystack = [app.name, app.genericName, app.comment, app.keywords.join(" ")].join(" ").toLowerCase();
            return !app.noDisplay && terms.every(term => haystack.includes(term));
        }).sort((a, b) => {
            const aStarts = a.name.toLowerCase().startsWith(query);
            const bStarts = b.name.toLowerCase().startsWith(query);
            return Number(bStarts) - Number(aStarts) || a.name.localeCompare(b.name);
        });
    }

    function launch(app) {
        if (!app) return;
        if (app.runInTerminal) {
            Quickshell.execDetached({ command: Config.terminalCommand.concat(Array.from(app.command)), workingDirectory: app.workingDirectory });
        } else {
            app.execute();
        }
        ShellState.close();
    }

    function move(delta) {
        if (!list.count) return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    onOpened: { search.text = ""; list.currentIndex = 0; search.forceActiveFocus(); }
    onResultsChanged: list.currentIndex = 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14
        RowLayout {
            Label { text: "APPLICATIONS"; font.letterSpacing: 2; font.pixelSize: Config.scaledFontSize(11); Layout.fillWidth: true }
            CloseButton { panelTitle: "applications" }
        }
        SearchBox {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search your applications…"
            onAccepted: root.launch(root.results[list.currentIndex])
            Keys.onDownPressed: root.move(1)
            Keys.onUpPressed: root.move(-1)
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 4
                model: root.results
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 58
                    radius: Config.radius
                    color: ListView.isCurrentItem ? Theme.raised : mouse.containsMouse ? Theme.background : Theme.clear
                    Rectangle { width: 3; height: 24; anchors.verticalCenter: parent.verticalCenter; radius: 1; color: Theme.accent; visible: row.ListView.isCurrentItem }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12
                        Item {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Image {
                                id: icon
                                anchors.fill: parent
                                source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 30
                                sourceSize.height: 30
                            }
                            Label { anchors.centerIn: parent; visible: icon.status !== Image.Ready; text: row.modelData.name.slice(0, 1).toUpperCase(); color: Theme.accent; font.pixelSize: Config.scaledFontSize(22) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label { Layout.fillWidth: true; text: row.modelData.name }
                            Label { Layout.fillWidth: true; text: row.modelData.genericName || row.modelData.comment || row.modelData.id; color: Theme.muted; font.pixelSize: Config.scaledFontSize(11) }
                        }
                        Label { visible: row.ListView.isCurrentItem; text: "↵"; color: Theme.accent }
                    }
                    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(row.modelData) }
                }
            }
            EmptyState { anchors.centerIn: parent; width: parent.width - 30; visible: list.count === 0; title: "No applications found"; subtitle: "Try a different name or keyword." }
        }
        RowLayout {
            Label { text: "↑ ↓  navigate     ↵  launch"; font.pixelSize: Config.scaledFontSize(10); color: Theme.muted; Layout.fillWidth: true }
            Label { text: root.results.length + " apps"; font.pixelSize: Config.scaledFontSize(10); color: Theme.subtle }
        }
    }
}
