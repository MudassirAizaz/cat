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
    readonly property var history: {
        const notifications = server.trackedNotifications.values;
        return notifications.filter(n => !n.transient).slice().reverse();
    }
    readonly property var popups: {
        const notifications = server.trackedNotifications.values;
        return notifications.filter(n => popupIds.includes(n.id)).slice(-3).reverse();
    }
    readonly property int unread: history.filter(n => metadata[n.id]?.unread).length

    function removePopup(id) {
        popupIds = popupIds.filter(value => value !== id);
    }

    function hidePopups() {
        popupIds = [];
        // A transient has no history entry from which a hidden sticky popup can
        // be dismissed. Release it when DND or the history view hides popups.
        server.trackedNotifications.values.slice().forEach(notification => {
            if (notification.transient && metadata[notification.id]?.deadline === 0)
                notification.expire();
        });
    }

    function forget(id) {
        removePopup(id);
        const next = Object.assign({}, metadata);
        delete next[id];
        metadata = next;
    }

    function markRead() {
        const next = Object.assign({}, metadata);
        Object.keys(next).forEach(id => {
            next[id] = Object.assign({}, next[id]);
            next[id].unread = false;
        });
        metadata = next;
        hidePopups();
    }

    function clear() {
        history.slice().forEach(n => n.dismiss());
    }

    function timeFor(id) {
        return metadata[id] ? Qt.formatDateTime(new Date(metadata[id].received), "HH:mm") : "";
    }

    function receive(notification) {
        notification.tracked = true;
        const id = notification.id;
        const now = Date.now();
        const sticky = notification.expireTimeout === 0 || notification.urgency === NotificationUrgency.Critical;
        const duration = notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : Config.toastDuration;
        const viewingHistory = ShellState.panel === "notifications";
        const suppressed = doNotDisturb || viewingHistory;
        const next = Object.assign({}, metadata);
        next[id] = {
            received: now,
            unread: !viewingHistory,
            deadline: sticky && !(notification.transient && suppressed) ? 0 : now + duration
        };
        metadata = next;
        notification.closed.connect(() => root.forget(id));

        if (!notification.lastGeneration && !suppressed)
            popupIds = popupIds.filter(value => value !== id).concat([id]);

        Qt.callLater(() => {
            history.slice(Config.notificationLimit).forEach(n => n.dismiss());
        });
    }

    function expireDue(now) {
        server.trackedNotifications.values.slice().forEach(notification => {
            const entry = metadata[notification.id];
            if (!entry || entry.deadline <= 0 || now < entry.deadline)
                return;
            removePopup(notification.id);
            if (notification.transient)
                notification.expire();
        });
    }

    onDoNotDisturbChanged: {
        if (doNotDisturb)
            hidePopups();
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true

        onNotification: notification => root.receive(notification)
    }

    Timer {
        interval: 250
        running: root.popupIds.length > 0 || server.trackedNotifications.values.some(n => n.transient)
        repeat: true
        onTriggered: root.expireDue(Date.now())
    }
}
