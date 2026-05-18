pragma Singleton

import Quickshell

Singleton {
    readonly property bool visible: DashboardState.visible && DashboardState.tab === "apps"
    function toggle() { DashboardState.toggle("apps") }
    function show()   { DashboardState.open("apps") }
    function hide()   { DashboardState.close() }
}
