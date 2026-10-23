import QtQuick
import ".."

IconButton {
    property string panelTitle: "panel"
    iconName: "close"
    hint: "Close " + panelTitle
    focusPolicy: Qt.NoFocus
    onClicked: ShellState.close()
}
