pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    readonly property list<Notif> list: []
    readonly property list<Notif> popups: list.filter(n => n.popup)

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.list.push(notifComp.createObject(root, {
                popup:          true,
                notification:   notif,
                appName:        notif.appName,
                appIcon:        notif.appIcon,
                summary:        notif.summary,
                body:           notif.body,
                urgency:        notif.urgency,
                expireTimeout:  notif.expireTimeout
            }));
        }
    }

    IpcHandler {
        target: "notifs"

        function clear(): void {
            for (const notif of root.list) {
                notif.popup = false;
            }
        }
    }

    function send(appName, summary, body, icon, urgency, timeout) {
        root.list.push(notifComp.createObject(root, {
            popup:         true,
            appName:       appName  ?? "",
            appIcon:       icon     ?? "",
            summary:       summary  ?? "",
            body:          body     ?? "",
            urgency:       urgency  ?? NotificationUrgency.Normal,
            expireTimeout: timeout  ?? -1
        }));
    }

    component Notif: QtObject {
        id: notif

        property bool popup: true
        readonly property date time: new Date()
        readonly property string timeStr: {
            const diff = Time.date.getTime() - time.getTime();
            const m = Math.floor(diff / 60000);
            const h = Math.floor(m / 60);

            if (h < 1 && m < 1)
                return "now";
            if (h < 1)
                return `${m}m`;
            return `${h}h`;
        }

        // D-Bus notification object — null for internally-sent notifications
        property var notification: null

        // Flat display fields, populated from `notification` for D-Bus ones
        // or set directly via Notifs.send() for internal ones
        property string appName:  ""
        property string appIcon:  ""
        property string summary:  ""
        property string body:     ""
        property int    urgency:  NotificationUrgency.Normal
        property int    expireTimeout: -1

        readonly property Timer timer: Timer {
            running: true
            interval: notif.expireTimeout > 0 ? notif.expireTimeout : 20000
            onTriggered: { notif.popup = false; }
        }

        readonly property Connections conn: Connections {
            target: notif.notification != null ? notif.notification.Retainable : null

            function onDropped(): void {
                root.list.splice(root.list.indexOf(notif), 1);
            }

            function onAboutToDestroy(): void {
                notif.destroy();
            }
        }
    }

    Component {
        id: notifComp

        Notif {}
    }
}
