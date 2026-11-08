pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// notifications: a new one hits the island on top and a pulse flash, history lives as cards in quick settings
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values
    property var times: ({}) // id → when it arrived: Notification has no timestamp of its own
    signal arrived(var n)

    // long-task progress — the value hint (notify-send -h int:value:64 …): the bottom pulse strip
    readonly property var task: list.slice().reverse().find(n => n.hints?.value !== undefined) ?? null

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => {
            n.tracked = true;
            root.times = Object.assign({}, root.times, { [n.id]: Date.now() });
            if (!Skin.state.dnd || n.urgency === NotificationUrgency.Critical) root.arrived(n);
        }
    }

    function clear() { for (const n of list.slice()) n.dismiss(); }
    function ago(n, now) {
        const m = Math.floor((now - (times[n.id] ?? now)) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m} min` : `${Math.floor(m / 60)} h`;
    }

    // the count goes into state: the lock writes "3 notifications"
    onListChanged: if (Skin.state.unread !== list.length) Skin.state.unread = list.length
}
