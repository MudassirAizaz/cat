pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import ".."

Scope {
    id: root
    property bool doNotDisturb: false
    property var metadata: ({})
    property var popupIds: []
    readonly property var history: server.trackedNotifications.values.filter(n => !n.transient).slice().reverse()
    readonly property var popups: server.trackedNotifications.values.filter(n => popupIds.indexOf(n.id) !== -1).slice(-3).reverse()
    readonly property int unread: history.filter(n => metadata[n.id]?.unread).length

    function removePopup(id) {
        popupIds = popupIds.filter(value => value !== id);
    }

    function markRead() {
        const next = Object.assign({}, metadata);
        Object.keys(next).forEach(id => next[id] = Object.assign({}, next[id], { unread: false }));
        metadata = next;
        popupIds = [];
    }

    function clear() {
        history.slice().forEach(n => n.dismiss());
    }

    function timeFor(id) {
        return metadata[id] ? Qt.formatDateTime(new Date(metadata[id].received), "HH:mm") : "";
    }

    onDoNotDisturbChanged: {
        if (doNotDisturb) popupIds = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true

        onNotification: notification => {
            notification.tracked = true;
            const id = notification.id;
            const now = Date.now();
            const sticky = notification.expireTimeout === 0 || notification.urgency === NotificationUrgency.Critical;
            const duration = notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : Config.toastDuration;
            const next = Object.assign({}, root.metadata);
            const suppressed = root.doNotDisturb || ShellState.panel === "notifications";
            next[id] = { received: now, unread: ShellState.panel !== "notifications", deadline: sticky && !(notification.transient && suppressed) ? 0 : now + duration };
            root.metadata = next;
            notification.closed.connect(() => {
                root.removePopup(id);
                const remaining = Object.assign({}, root.metadata);
                delete remaining[id];
                root.metadata = remaining;
            });
            if (!notification.lastGeneration && !root.doNotDisturb && ShellState.panel !== "notifications")
                root.popupIds = root.popupIds.filter(value => value !== id).concat([id]);

            Qt.callLater(() => {
                const oldest = root.history.slice(Config.notificationLimit);
                oldest.forEach(n => n.dismiss());
            });
        }
    }

    Timer {
        interval: 250
        running: root.popupIds.length > 0 || server.trackedNotifications.values.some(n => n.transient)
        repeat: true
        onTriggered: {
            const now = Date.now();
            server.trackedNotifications.values.slice().forEach(n => {
                const entry = root.metadata[n.id];
                if (entry && entry.deadline > 0 && now >= entry.deadline) {
                    root.removePopup(n.id);
                    if (n.transient) n.expire();
                }
            });
        }
    }
}
