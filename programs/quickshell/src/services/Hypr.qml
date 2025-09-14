pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel?.wayland?.activated ? Hyprland.activeToplevel : null
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    property var keyboard
    readonly property bool capsLock: keyboard?.capsLock ?? false
    readonly property bool numLock: keyboard?.numLock ?? false
    readonly property string defaultKbLayout: keyboard?.layout.split(",")[0] ?? "??"
    readonly property string kbLayoutFull: keyboard?.active_keymap ?? "Unknown"
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? "??"
    readonly property var kbMap: new Map()

    readonly property var windowsByWorkspace: toplevels.values.reduce((acc, curr) => {
        const id = curr?.workspace?.id;

        if (id != null) {
            acc[id] = acc[id] ?? [];
            acc[id].push(curr);
        }

        return acc;
    }, {}) ?? {}

    function dispatch(request: string): void {
        Hyprland.dispatch(request);
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (n === "configreloaded") {
                setDynamicConfsProc.running = true;
            } else if (n === "activelayout") {
                devicesProc.running = true;
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }
    }

    Process {
        id: devicesProc

        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: root.keyboard = JSON.parse(text).keyboards.find(k => k.main)
        }
    }

    Process {
        id: setDynamicConfsProc

        running: true
        command: ["hyprctl", "--batch", "keyword bindln ,Caps_Lock,global,caelestia:reloadDevices;keyword bindln ,Num_Lock,global,caelestia:reloadDevices"]
    }

    IpcHandler {
        target: "hypr"

        function reloadDevices(): void {
            devicesProc.running = true;
        }
    }

    /*CustomShortcut {
        name: "reloadDevices"
        description: "Reload devices"
        onPressed: devicesProc.running = true
        onReleased: devicesProc.running = true
    }*/
}
