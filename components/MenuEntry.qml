import QtQuick
import QtQuick.Layouts
import ".."

ActionButton {
    id: root
    property string title: ""
    property string detail: ""
    property string iconName: "apps"
    property bool hasSubmenu: true
    implicitHeight: detail ? 52 : 44
    implicitWidth: 280
    Accessible.name: title
    signal moveRequested(int delta)
    Keys.onUpPressed: moveRequested(-1)
    Keys.onDownPressed: moveRequested(1)
    Keys.onRightPressed: {
        if (hasSubmenu) clicked();
        else ShellState.forward();
    }
    Keys.onLeftPressed: ShellState.back()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    contentItem: Item {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14
            Icon {
                name: root.iconName
                color: root.destructive ? Theme.danger : Theme.accent
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    text: root.title
                    color: root.destructive ? Theme.danger : Theme.foreground
                    font.pixelSize: Config.scaledFontSize(12)
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    visible: root.detail.length > 0
                    text: root.detail
                    color: Theme.muted
                    font.pixelSize: Config.scaledFontSize(10)
                }
            }
            Icon {
                visible: root.hasSubmenu
                name: "chevron-right"
                color: Theme.subtle
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
        }
        opacity: root.enabled ? 1 : 0.4
    }
}
