pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"

PanelFrame {
    id: root
    panelName: "theme"
    centered: true
    panelWidth: 390
    panelHeight: 360
    function focusEntry(index) {
        if (!entries.count) return;
        const wrapped = (index + entries.count) % entries.count;
        entries.itemAt(wrapped)?.forceActiveFocus(Qt.TabFocusReason);
    }
    onOpened: {
        const index = entries.model.findIndex(entry => entry.id === Theme.palette);
        focusEntry(Math.max(0, index));
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        RowLayout {
            Label {
                text: "THEME"
                font.pixelSize: Config.scaledFontSize(11)
                font.letterSpacing: 2
                Layout.fillWidth: true
            }
            CloseButton {
                panelTitle: "theme"
            }
        }
        Label {
            text: "Choose a colour palette"
            color: Theme.muted
            font.pixelSize: Config.scaledFontSize(11)
        }
        Repeater {
            id: entries
            model: Object.keys(Theme.palettes).map(id => ({
                        id,
                        title: Theme.palettes[id].name || id.replace(/-/g, " ")
                    }))
            ActionButton {
                id: themeRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 42
                selected: Theme.palette === modelData.id
                Keys.onUpPressed: root.focusEntry(index - 1)
                Keys.onDownPressed: root.focusEntry(index + 1)
                Keys.onLeftPressed: ShellState.back()
                Keys.onRightPressed: ShellState.forward()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                contentItem: RowLayout {
                    spacing: 10
                    Rectangle {
                        Layout.leftMargin: 12
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        radius: 8
                        color: Theme.palettes[themeRow.modelData.id].accent
                    }
                    Label {
                        text: themeRow.modelData.title
                        Layout.fillWidth: true
                        font.pixelSize: Config.scaledFontSize(12)
                    }
                    Icon {
                        name: "check"
                        visible: themeRow.selected
                        color: Theme.onAccent
                        Layout.rightMargin: 12
                        implicitWidth: 15
                        implicitHeight: 15
                    }
                }
                onClicked: Theme.palette = modelData.id
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
