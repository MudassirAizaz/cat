pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

PanelFrame {
    id: root
    panelName: "window"
    mask: WindowInput.ready ? bodyRegion : null
    readonly property Region bodyRegion: Region { item: root.panelBody }
    panelWidth: 440
    panelHeight: WindowState.inspectionAvailable ? content.implicitHeight + 36 : 220
    onOpened: WindowState.capture()
    readonly property var targetWindow: WindowState.inspectedWindow
    readonly property var application: WindowState.applicationFor(targetWindow)
    readonly property var windowData: targetWindow?.lastIpcObject || {}
    readonly property var details: [
        { label: "Application ID", value: application.id || "—" },
        { label: "Size", value: windowData.size?.length === 2 ? windowData.size.join(" × ") : "—" },
        { label: "Process ID", value: String(windowData.pid ?? "—") }
    ]

    Binding {
        target: WindowInput
        property: "active"
        value: root.visible
    }
    Connections {
        target: WindowInput
        function onPressed(x, y) {
            if (!root.visible)
                return;
            const point = root.panelBody.mapFromGlobal(x, y);
            if (point.x < 0 || point.y < 0 || point.x >= root.panelBody.width || point.y >= root.panelBody.height)
                ShellState.close();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 18
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        visible: WindowState.inspectionAvailable

        ColumnLayout {
            id: content
            width: parent.width
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ApplicationIcon {
                    iconName: root.application.icon
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    fallbackColor: Theme.accent
                }
                Label {
                    objectName: "windowApplication"
                    Layout.fillWidth: true
                    text: root.application.name
                    font.pixelSize: Config.scaledFontSize(17)
                }
                CloseButton { panelTitle: "window details" }
            }
            Label {
                objectName: "windowTitle"
                Layout.fillWidth: true
                text: root.targetWindow?.title || "Untitled window"
                color: Theme.muted
                wrapMode: Text.Wrap
                maximumLineCount: 6
                font.pixelSize: Config.scaledFontSize(12)
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }
            Repeater {
                model: root.details
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Label {
                        Layout.preferredWidth: 130
                        Layout.alignment: Qt.AlignTop
                        text: parent.modelData.label
                        color: Theme.subtle
                        font.pixelSize: Config.scaledFontSize(10)
                    }
                    Label {
                        objectName: "windowDetail"
                        Layout.fillWidth: true
                        text: parent.modelData.value
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: Config.scaledFontSize(11)
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        visible: !WindowState.inspectionAvailable
        CloseButton {
            panelTitle: "window details"
            Layout.alignment: Qt.AlignRight
        }
        EmptyState {
            objectName: "windowUnavailable"
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "No window selected"
            subtitle: "The window may have closed. Select an application to inspect it."
        }
    }
}
