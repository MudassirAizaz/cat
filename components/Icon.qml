import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property string name: "apps"
    property color color: Theme.foreground
    property real level: 1
    implicitWidth: 18
    implicitHeight: 18

    // One consistent 24px vector grid; no icon font or system theme required.
    readonly property var paths: ({
            menu: "M4 6h16 M4 12h16 M4 18h16",
            apps: "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h6v6h-6z",
            theme: "M12 3a9 9 0 1 0 0 18h1a2 2 0 0 0 1-4l-1-1a2 2 0 0 1 2-3h2a4 4 0 0 0 4-4c-2-4-5-6-9-6z M7 10h.1 M11 7h.1 M16 9h.1",
            wallpaper: "M3 4h18v16H3z M3 16l5-5 4 4 3-3 6 6 M15 9h.1",
            history: "M3 12a9 9 0 1 0 3-7 M3 4v5h5 M12 7v5l3 2",
            clipboard: "M9 4h6l1 2h4v15H4V6h4z M9 4v3h6V4 M8 12h8 M8 16h8",
            volume: "M3 9h4l5-4v14l-5-4H3z M16 8a6 6 0 0 1 0 8 M19 5a10 10 0 0 1 0 14",
            "volume-low": "M3 9h4l5-4v14l-5-4H3z M16 8a6 6 0 0 1 0 8",
            "volume-muted": "M3 9h4l5-4v14l-5-4H3z M17 9l5 6 M22 9l-5 6",
            microphone: "M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1-6 0z M5 10v2a7 7 0 0 0 14 0v-2 M12 19v3 M8 22h8",
            "microphone-muted": "M3 3l18 18 M9 5a3 3 0 0 1 6 0v6 M9 9v3a3 3 0 0 0 5 2 M5 10v2a7 7 0 0 0 12 5 M19 10v2 M12 19v3 M8 22h8",
            battery: "M4 6h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z M23 10v4",
            "battery-charging": "M4 6h3 M15 6h3a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-3 M7 18H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2 M23 10v4 M12 3L8 12h6l-4 9",
            wifi: "M2 8a16 16 0 0 1 20 0 M5 12a11 11 0 0 1 14 0 M8 16a6 6 0 0 1 8 0 M11.5 20h1",
            "wifi-off": "M2 2l20 20 M2 8a16 16 0 0 1 3-2 M10 4a16 16 0 0 1 12 4 M5 12a11 11 0 0 1 4-2 M15 10a11 11 0 0 1 4 2 M8 16a6 6 0 0 1 8 0 M11.5 20h1",
            ethernet: "M4 3h16v12H4z M9 15v5 M15 15v5 M6 20h12 M8 7v3 M12 7v3 M16 7v3",
            lock: "M7 10V7a5 5 0 0 1 10 0v3 M5 10h14v11H5z M12 14v3",
            check: "M5 12l4 4L19 6",
            close: "M6 6l12 12 M18 6L6 18",
            "chevron-right": "M9 5l7 7-7 7",
            suspend: "M20 15A9 9 0 0 1 9 4a9 9 0 1 0 11 11z",
            hibernate: "M12 2v20 M3 7l18 10 M3 17L21 7 M9 4l3 3 3-3 M9 20l3-3 3 3",
            logout: "M10 3H4v18h6 M9 12h12 M16 7l5 5-5 5",
            restart: "M20 10a8 8 0 1 0-1 7 M20 3v7h-7",
            leaf: "M20 4C9 2 3 7 4 14c1 7 11 8 14 1 2-4 2-7 2-11z M4 21L15 9",
            balanced: "M12 3v18 M5 7h14 M5 7l-3 7h6z M19 7l-3 7h6z M7 21h10",
            performance: "M13 2L4 14h7l-1 8 10-13h-7z",
            power: "M12 2v10 M6 5a9 9 0 1 0 12 0"
        })

    Item {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: 1.7
                fillColor: Theme.clear
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.paths[root.name] || root.paths.apps
                }
            }
        }
        Rectangle {
            visible: root.name === "battery"
            x: 5
            y: 9
            width: Math.round(12 * Math.max(0, Math.min(1, root.level)))
            height: 6
            radius: 1
            color: root.color
        }
    }
}
