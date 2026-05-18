pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool active: false
    property bool _pendingRestart: false

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProcess.running = true
    }

    Process {
        id: pollProcess
        command: ["systemctl", "is-active", "proxy.service"]
        onExited: {
            const was = root.active
            root.active = (pollProcess.exitCode === 0)
            if (was === root.active) return

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
    }

    Process { id: notifyProcess }
    Process {
        id: actionProcess
        onExited: Qt.callLater(() => pollProcess.running = true)
    }

    function start()   { actionProcess.command = ["sudo", "systemctl", "start",   "proxy.service"]; actionProcess.running = true }
    function stop()    { actionProcess.command = ["sudo", "systemctl", "stop",    "proxy.service"]; actionProcess.running = true }
    function restart() { _pendingRestart = true; stop() }
    function toggle()  { active ? stop() : start() }
}
