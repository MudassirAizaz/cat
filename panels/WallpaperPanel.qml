pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

PanelFrame {
    id: root
    panelName: "wallpaper"
    centered: true
    panelWidth: 680
    panelHeight: 620
    readonly property GridView galleryView: galleryLoader.item as GridView
    property int galleryIndex: 0
    property real galleryScrollY: 0
    onOpened: {
        WallpaperState.refresh();
        galleryView?.forceActiveFocus();
    }

    function imageUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function applyCurrentWallpaper() {
        const index = galleryView?.currentIndex ?? root.galleryIndex;
        const wallpaper = WallpaperState.wallpapers[index];
        if (wallpaper)
            WallpaperState.set(wallpaper.path);
    }

    // The grid has its own focus scope; handle panel shortcuts at window level.
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        context: Qt.WindowShortcut
        onActivated: ShellState.close()
    }
    Shortcut {
        sequence: "Backspace"
        enabled: root.visible
        context: Qt.WindowShortcut
        onActivated: ShellState.back()
    }
    Shortcut {
        sequence: "Shift+Backspace"
        enabled: root.visible
        context: Qt.WindowShortcut
        onActivated: ShellState.forward()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        RowLayout {
            Label {
                text: "WALLPAPER"
                font.pixelSize: Config.scaledFontSize(11)
                font.letterSpacing: 2
                Layout.fillWidth: true
            }
            CloseButton {
                panelTitle: "wallpapers"
            }
        }
        Label {
            text: "~/Pictures/Wallpapers"
            color: Theme.muted
            font.pixelSize: Config.scaledFontSize(11)
            Layout.fillWidth: true
        }
        Label {
            visible: WallpaperState.error.length > 0
            text: WallpaperState.error
            color: Theme.danger
            font.pixelSize: Config.scaledFontSize(11)
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Loader {
                id: galleryLoader
                objectName: "wallpaperGalleryLoader"
                anchors.fill: parent
                active: root.visible
                onLoaded: {
                    const view = item as GridView;
                    view.currentIndex = Math.min(root.galleryIndex, Math.max(0, view.count - 1));
                    view.contentY = Math.min(root.galleryScrollY, Math.max(0, view.contentHeight - view.height));
                    view.forceActiveFocus();
                }
                sourceComponent: GridView {
                    id: gallery
                    objectName: "wallpaperGallery"
                    Component.onDestruction: {
                        root.galleryIndex = currentIndex;
                        root.galleryScrollY = contentY;
                    }
                    anchors.fill: parent
                    clip: true
                    cellWidth: 206
                    cellHeight: 146
                    model: WallpaperState.wallpapers
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: true
                    keyNavigationWraps: true
                    highlightMoveDuration: 0
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                    onCountChanged: {
                        if (count && currentIndex < 0)
                            currentIndex = 0;
                    }
                    Keys.onReturnPressed: root.applyCurrentWallpaper()
                    Keys.onEnterPressed: root.applyCurrentWallpaper()
                    highlight: Rectangle {
                        width: gallery.cellWidth - 10
                        height: gallery.cellHeight - 10
                        color: Theme.clear
                        border.color: Theme.accent
                        border.width: 1
                        radius: Config.radius
                        visible: gallery.activeFocus
                        z: 2
                    }
                    delegate: ActionButton {
                        id: wallpaperCard
                        required property var modelData
                        required property int index
                        width: gallery.cellWidth - 10
                        height: gallery.cellHeight - 10
                        implicitWidth: width
                        implicitHeight: height
                        padding: 0
                        selected: WallpaperState.currentPath === modelData.path || WallpaperState.pendingPath === modelData.path
                        enabled: !WallpaperState.busy
                        contentItem: Item {
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6
                                radius: Config.radius - 2
                                color: Theme.surface
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: root.imageUrl(wallpaperCard.modelData.path)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 188
                                    sourceSize.height: 92
                                }
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 30
                                    color: Theme.background
                                    opacity: 0.94
                                }
                                Label {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 9
                                    anchors.rightMargin: 9
                                    anchors.bottom: parent.bottom
                                    height: 30
                                    text: wallpaperCard.modelData.name
                                    font.pixelSize: Config.scaledFontSize(10)
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    width: 9
                                    height: 9
                                    radius: 5
                                    color: Theme.accent
                                    visible: wallpaperCard.selected
                                }
                            }
                        }
                        onClicked: {
                            gallery.currentIndex = index;
                            WallpaperState.set(modelData.path);
                        }
                    }
                }
            }
            EmptyState {
                anchors.centerIn: parent
                visible: !WallpaperState.busy && (root.galleryView?.count || 0) === 0 && !WallpaperState.error
                title: "No wallpapers found"
                subtitle: "Add JPG or PNG images to ~/Pictures/Wallpapers."
            }
        }
    }
}
