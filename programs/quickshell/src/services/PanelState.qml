pragma Singleton

import Quickshell

Singleton {
    readonly property string panel: {
        const t = DashboardState.tab
        return DashboardState.visible && t !== "apps" && t !== "home" ? t : ""
    }
    readonly property bool visible: panel !== ""
    function open(name: string)   { DashboardState.open(name) }
    function close()               { DashboardState.close() }
    function toggle(name: string) { DashboardState.toggle(name) }
}
