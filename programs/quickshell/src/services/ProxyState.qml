pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.floweyshell 1.0

Singleton {
    id: root

    readonly property bool active: SystemdWatcher.proxyActive
    property bool _pendingRestart: false

    onActiveChanged: {
        notifyProcess.command = [
            "notify-send", "-a", "floweyshell", "-i", "network-vpn",
            "Proxy", root.active ? "Proxy is now active" : "Proxy stopped"
        ]
        notifyProcess.running = true

        if (!root.active && root._pendingRestart) {
            root._pendingRestart = false
            actionProcess.command = ["sudo", "systemctl", "start", "proxy.service"]
            actionProcess.running = true
        }
    }

    Process { id: notifyProcess }
    Process { id: actionProcess }

    function start()   { actionProcess.command = ["sudo", "systemctl", "start",   "proxy.service"]; actionProcess.running = true }
    function stop()    { actionProcess.command = ["sudo", "systemctl", "stop",    "proxy.service"]; actionProcess.running = true }
    function restart() { _pendingRestart = true; stop() }
    function toggle()  { active ? stop() : start() }
}
