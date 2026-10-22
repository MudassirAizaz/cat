import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    property string title: ""
    property string subtitle: ""
    spacing: 10
    Label { Layout.alignment: Qt.AlignHCenter; text: "· · ·"; color: Theme.accent; font.pixelSize: Config.scaledFontSize(24) }
    Label { Layout.alignment: Qt.AlignHCenter; text: parent.title; font.pixelSize: Config.scaledFontSize(15) }
    Label {
        Layout.fillWidth: true
        text: parent.subtitle
        color: Theme.muted
        font.pixelSize: Config.scaledFontSize(11)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
