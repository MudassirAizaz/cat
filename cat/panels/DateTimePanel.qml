pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"

PanelFrame {
    id: root
    panelName: "calendar"
    panelWidth: 360
    panelHeight: 430
    readonly property date now: clock.date
    property date displayedMonth: new Date()

    function changeMonth(delta) {
        const date = new Date(displayedMonth);
        date.setDate(1);
        date.setMonth(date.getMonth() + delta);
        displayedMonth = date;
    }

    function showToday() {
        displayedMonth = new Date();
    }

    onOpened: showToday()

    SystemClock {
        id: clock
        enabled: root.visible
        precision: SystemClock.Seconds
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    objectName: "calendarTime"
                    text: Qt.formatDateTime(root.now, "HH:mm:ss")
                    font.pixelSize: Config.scaledFontSize(28)
                    color: Theme.accent
                }
                Label {
                    objectName: "calendarDate"
                    Layout.fillWidth: true
                    text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
                    font.pixelSize: Config.scaledFontSize(11)
                    color: Theme.muted
                }
            }
            CloseButton {
                panelTitle: "calendar"
                Layout.alignment: Qt.AlignTop
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.fillWidth: true
            ActionButton {
                objectName: "previousMonth"
                text: "‹"
                hint: "Previous month"
                implicitWidth: 30
                enabled: calendar.year > 1 || calendar.month > 0
                onClicked: root.changeMonth(-1)
            }
            Label {
                Layout.fillWidth: true
                text: Qt.formatDateTime(root.displayedMonth, "MMMM yyyy")
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Config.scaledFontSize(13)
            }
            ActionButton {
                objectName: "nextMonth"
                text: "›"
                hint: "Next month"
                implicitWidth: 30
                enabled: calendar.year < 9999 || calendar.month < 11
                onClicked: root.changeMonth(1)
            }
        }

        Controls.DayOfWeekRow {
            Layout.fillWidth: true
            implicitHeight: 24
            topPadding: 0
            bottomPadding: 0
            spacing: calendar.spacing
            locale: calendar.locale
            delegate: Label {
                required property string shortName
                text: shortName
                color: Theme.muted
                font.pixelSize: Config.scaledFontSize(10)
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Controls.MonthGrid {
            id: calendar
            objectName: "monthGrid"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 198
            month: root.displayedMonth.getMonth()
            year: root.displayedMonth.getFullYear()
            spacing: 4
            locale: Qt.locale()
            delegate: Item {
                id: day
                objectName: "calendarDay"
                required property var model
                readonly property bool currentMonth: model.month === calendar.month
                readonly property bool today: model.day === root.now.getDate()
                    && model.month === root.now.getMonth() && model.year === root.now.getFullYear()

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 14
                    visible: day.today
                    color: Theme.accent
                }
                Label {
                    anchors.fill: parent
                    text: day.model.day
                    horizontalAlignment: Text.AlignHCenter
                    color: day.today ? Theme.onAccent : day.currentMonth ? Theme.foreground : Theme.subtle
                    font.pixelSize: Config.scaledFontSize(12)
                }
            }
        }

        ActionButton {
            objectName: "calendarToday"
            text: "Today"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.showToday()
        }
    }
}
