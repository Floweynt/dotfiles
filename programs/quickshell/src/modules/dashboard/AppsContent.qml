pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import qs
import qs.services
import qs.components
import qs.modules.launcher

Item {
    id: root

    function focusSearch() { searchField.forceActiveFocus() }

    // -------------------------------------------------------------------------
    // Runtime state
    // -------------------------------------------------------------------------
    property var entries: []
    property int selectedIndex: 0
    property bool _trackMouse: false
    property var pathExecutables: []
    property var _pathBuf: []
    property string _deferredCmd: ""

    // Fires deferred command after overlay is dismissed
    Timer {
        id: deferredTimer; interval: 250
        onTriggered: {
            if (root._deferredCmd) {
                cliProcess.command = ["bash", "-c", root._deferredCmd]
                cliProcess.startDetached()
                root._deferredCmd = ""
            }
        }
    }

    // PATH executables for /cli autocomplete
    Process {
        id: pathLoader
        command: ["bash", "-c", "compgen -c | sort -u"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { const l = data.trim(); if (l) root._pathBuf.push(l) }
        }
        Component.onCompleted: running = true
        onExited: { root.pathExecutables = root._pathBuf; root._pathBuf = [] }
    }

    Process { id: cliProcess }

    // Background processes for /nix gc, /nix repair, and /update
    readonly property string _nixStoreBin: "/run/current-system/sw/bin/nix-store"
    readonly property string _nixosBin:    "/run/current-system/sw/bin/nixos-rebuild"

    Process {
        id: nixGcProc
        command: ["pkexec", "/bin/sh", "-c", root._nixStoreBin + " --gc"]
        onExited: {
            notifyProc.command = ["notify-send", "-a", "floweyshell", "-i", "system-software-update",
                "Nix", nixGcProc.exitCode === 0 ? "Garbage collection complete" : "Garbage collection failed"]
            notifyProc.running = true
        }
    }
    Process {
        id: nixRepairProc
        command: ["pkexec", "/bin/sh", "-c", root._nixStoreBin + " --verify --check-contents --repair"]
        onExited: {
            notifyProc.command = ["notify-send", "-a", "floweyshell", "-i", "system-software-update",
                "Nix", nixRepairProc.exitCode === 0 ? "Store repair complete" : "Store repair failed"]
            notifyProc.running = true
        }
    }
    Process {
        id: updateProc
        command: ["pkexec", "/bin/sh", "-c",
                  root._nixosBin + " switch --flake /persist/@home/dotfiles#nix-fw16"]
        onExited: {
            notifyProc.command = ["notify-send", "-a", "floweyshell", "-i", "system-software-update",
                "NixOS", updateProc.exitCode === 0 ? "System updated successfully" : "Update failed (exit " + updateProc.exitCode + ")"]
            notifyProc.running = true
        }
    }
    Process { id: notifyProc }

    Connections {
        target: ProxyState
        function onActiveChanged() { if (DashboardState.visible && DashboardState.tab === "apps") root.updateEntries() }
    }

    // -------------------------------------------------------------------------
    // Subcommand infrastructure
    // -------------------------------------------------------------------------
    function resolveSubcommandEntries(subcommands, args) {
        const lc = args.toLowerCase().trim()
        const filtered = lc ? subcommands.filter(s => s.name.startsWith(lc)) : subcommands
        return filtered.map(s => ({
            name: s.name, iconName: "", iconGlyph: s.icon ?? "",
            categories: [], description: s.description ?? "",
            keepOpen: s.keepOpen ?? false, run: s.run
        }))
    }

    function resolveSubcommandSuggestion(subcommands, args) {
        if (!args) return ""
        const match = subcommands.find(s => s.name.startsWith(args) && s.name !== args)
        return match ? match.name.slice(args.length) : ""
    }

    function cmdDesc(cmd) {
        return typeof cmd.description === "function" ? cmd.description() : (cmd.description ?? "")
    }

    // -------------------------------------------------------------------------
    // Command registry
    // -------------------------------------------------------------------------
    readonly property var commandRegistry: [
        { name: "cli",        description: "Run a shell command",     icon: "" },
        { name: "search",     description: "Search the web",          icon: "󰖟", argsHint: true },
        { name: "screenshot", description: "Take a screenshot",       icon: "",
          subcommands: [
              { name: "area",   description: "Select a region",       icon: "", run: () => { root._deferredCmd = "mkdir -p /tmp/screenshots && grimblast --notify copysave area /tmp/screenshots/" } },
              { name: "screen", description: "Capture full screen",   icon: "", run: () => { root._deferredCmd = "mkdir -p /tmp/screenshots && grimblast --notify copysave screen /tmp/screenshots/" } },
              { name: "active", description: "Capture active window", icon: "", run: () => { root._deferredCmd = "mkdir -p /tmp/screenshots && grimblast --notify copysave active /tmp/screenshots/" } },
          ]
        },
        { name: "proxy",      description: () => ProxyState.active ? "Proxy: active" : "Proxy: inactive", icon: "󰖟",
          subcommands: [
              { name: "start",   description: "Start the proxy",   icon: "",  run: () => ProxyState.start()   },
              { name: "stop",    description: "Stop the proxy",    icon: "󰅙",  run: () => ProxyState.stop()    },
              { name: "restart", description: "Restart the proxy", icon: "󰜉", run: () => ProxyState.restart() },
          ]
        },
        { name: "audio",     description: "Audio devices",            icon: "󰽴", keepOpen: true, run: () => DashboardState.switchTab("audio") },
        { name: "net",       description: "WiFi networks",            icon: "󱋊", keepOpen: true, run: () => DashboardState.switchTab("net") },
        { name: "bluetooth", description: "Bluetooth devices",        icon: "󰂯", keepOpen: true, run: () => DashboardState.switchTab("bluetooth") },
        { name: "perf",      description: "Performance monitor",      icon: "󰄬", keepOpen: true, run: () => DashboardState.switchTab("perf") },
        { name: "sys",       description: "System information",       icon: "󰍛", keepOpen: true, run: () => DashboardState.switchTab("sys") },
        { name: "menu",      description: "Quick settings",           icon: "󰒓", keepOpen: true, run: () => DashboardState.switchTab("menu") },
        { name: "dashboard", description: "Go to home",               icon: "󰋜", keepOpen: true, run: () => DashboardState.switchTab("home") },
        { name: "update",    description: "Rebuild NixOS flake",      icon: "󱄅",
          run: () => {
              notifyProc.command = ["notify-send", "-a", "floweyshell", "NixOS", "Rebuilding system…"]; notifyProc.running = true
              updateProc.running = true
          }
        },
        { name: "suspend",   description: "Suspend the system",       icon: "󰒲", run: () => { cliProcess.command = ["systemctl", "suspend"]; cliProcess.startDetached() } },
        { name: "reboot",    description: "Reboot the system",        icon: "󰜉", run: () => { cliProcess.command = ["systemctl", "reboot"];  cliProcess.startDetached() } },
        { name: "br",        description: "Screen brightness",        icon: "󰃟", argsHint: true },
        { name: "nix",       description: "Nix/NixOS tools",          icon: "",
          subcommands: [
              { name: "gc",     description: "Collect garbage",       icon: "󰃮",
                run: () => {
                    notifyProc.command = ["notify-send", "-a", "floweyshell", "Nix", "Garbage collection started…"]; notifyProc.running = true
                    nixGcProc.running = true
                }
              },
              { name: "repair", description: "Repair nix store",      icon: "󰒔",
                run: () => {
                    notifyProc.command = ["notify-send", "-a", "floweyshell", "Nix", "Store repair started…"]; notifyProc.running = true
                    nixRepairProc.running = true
                }
              },
              { name: "gen",    description: "Manage NixOS generations", icon: "󱚢", keepOpen: true,
                run: () => DashboardState.switchTab("gen")
              },
          ]
        },
    ]

    // -------------------------------------------------------------------------
    // Command routing
    // -------------------------------------------------------------------------
    function getCommandEntries(name, args) {
        if (name === "cli") {
            const cmd = args.trim()
            return [{ name: cmd ? "Run: " + cmd : "Run Command", iconName: "", iconGlyph: "",
                categories: ["TerminalEmulator"],
                description: cmd ? "" : "Type /cli <command> to run a shell command",
                keepOpen: !cmd,
                run: () => {
                    if (cmd) { cliProcess.command = ["sh", "-c", cmd]; cliProcess.startDetached() }
                    else { searchField.text = "/cli "; searchField.cursorPosition = 5 }
                }
            }]
        }
        if (name === "search") {
            const query = args.trim()
            return [{ name: query ? "Search: " + query : "Web Search", iconName: "", iconGlyph: "󰖟",
                categories: ["WebBrowser"], description: query ? "duckduckgo.com" : "Type /search <query>",
                keepOpen: !query,
                run: () => {
                    if (query) { cliProcess.command = ["librewolf", "--new-tab", "https://duckduckgo.com/?q=" + encodeURIComponent(query)]; cliProcess.startDetached() }
                    else { searchField.text = "/search "; searchField.cursorPosition = 8 }
                }
            }]
        }
        if (name === "br") {
            const arg = args.trim()
            function brEntry(label, desc, val) {
                return { name: label, iconName: "", iconGlyph: "󰃟", categories: [], description: desc, keepOpen: false,
                    run: () => { cliProcess.command = ["brightnessctl", "set", val]; cliProcess.startDetached() } }
            }
            if (arg) {
                let v = arg.startsWith("+") ? "+" + arg.slice(1).replace(/%$/, "") + "%"
                      : arg.startsWith("-") ? arg.slice(1).replace(/%$/, "") + "%-"
                      : arg.replace(/%$/, "") + "%"
                return [brEntry("Set brightness: " + arg, "", v)]
            }
            return [brEntry("10%","Set brightness to 10%","10%"), brEntry("25%","Set brightness to 25%","25%"),
                    brEntry("50%","Set brightness to 50%","50%"), brEntry("75%","Set brightness to 75%","75%"),
                    brEntry("100%","Set brightness to 100%","100%")]
        }

        const reg = commandRegistry.find(c => c.name === name)
        if (!reg) return []
        if (reg.subcommands) return resolveSubcommandEntries(reg.subcommands, args)
        if (reg.run) return [{ name: reg.name, iconName: "", iconGlyph: reg.icon ?? "", categories: [], description: cmdDesc(reg), keepOpen: reg.keepOpen ?? false, run: reg.run }]
        return []
    }

    function getCommandSuggestion(name, args) {
        if (name === "cli") {
            if (!args) return ""
            const match = pathExecutables.find(e => e.startsWith(args))
            return match ? match.slice(args.length) : ""
        }
        const reg = commandRegistry.find(c => c.name === name)
        if (reg?.subcommands) return resolveSubcommandSuggestion(reg.subcommands, args)
        return ""
    }

    property string suggestion: {
        const text = searchField.text
        if (!text) return ""
        if (text.startsWith("/")) {
            const partial = text.slice(1)
            const active = commandRegistry.find(c => partial === c.name || partial.startsWith(c.name + " "))
            if (active) {
                const args = partial.startsWith(active.name + " ") ? partial.slice(active.name.length + 1) : ""
                return getCommandSuggestion(active.name, args)
            }
            if (partial && !partial.includes(" ")) {
                const match = commandRegistry.find(c => c.name.startsWith(partial) && c.name !== partial)
                if (match) return match.name.slice(partial.length)
            }
            return ""
        }
        const first = entries.find(e => !e._isCommand)
        if (first && first.name.toLowerCase().startsWith(text.toLowerCase()))
            return first.name.slice(text.length)
        return ""
    }

    function buildEntry(e) {
        return { name: e.name, iconName: e.icon ?? "", categories: e.categories ?? [],
            description: e.genericName || e.comment || "", keepOpen: false, run: () => e.execute() }
    }

    function makeCommandEntry(cmd) {
        return { name: "/" + cmd.name, iconName: "", iconGlyph: cmd.icon,
            categories: [], description: cmdDesc(cmd), _isCommand: true, keepOpen: true,
            run: () => { searchField.text = "/" + cmd.name + (cmd.subcommands || cmd.argsHint ? " " : ""); searchField.cursorPosition = searchField.text.length }
        }
    }

    function updateEntries() {
        root._trackMouse = false
        const raw = searchField.text
        const query = raw.trim()

        if (query.startsWith("/")) {
            const partial = query.slice(1)
            const active = commandRegistry.find(c => partial === c.name || partial.startsWith(c.name + " "))
            if (active) {
                const args = partial.startsWith(active.name + " ") ? partial.slice(active.name.length + 1) : ""
                entries = getCommandEntries(active.name, args)
                selectedIndex = 0
                return
            }
            const lc = partial.toLowerCase()
            const cmds = lc ? commandRegistry.filter(c => c.name.startsWith(lc)) : commandRegistry
            entries = cmds.map(c => makeCommandEntry(c))
            selectedIndex = 0
            return
        }

        const lq = query.toLowerCase()
        const apps = DesktopEntries.applications.values
        if (!apps) return
        const filtered = lq
            ? apps.filter(e => e.name.toLowerCase().includes(lq) || (e.keywords && e.keywords.some(k => k.toLowerCase().includes(lq))))
            : apps
        entries = [...filtered.map(e => buildEntry(e)), ...commandRegistry.map(c => makeCommandEntry(c))]
        selectedIndex = 0
    }

    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < entries.length) {
            const entry = entries[selectedIndex]
            entry.run()
            if (!entry.keepOpen) {
                if (root._deferredCmd) { DashboardState.close(); deferredTimer.start() }
                else DashboardState.close()
            }
        }
    }

    Connections {
        target: DashboardState
        function onTabChanged() {
            if (DashboardState.tab === "apps") {
                searchField.text = ""
                root.updateEntries()
            }
        }
        function onVisibleChanged() {
            if (DashboardState.visible && DashboardState.tab === "apps") {
                searchField.text = ""
                root.updateEntries()
            } else if (!DashboardState.visible && root._deferredCmd) {
                deferredTimer.start()
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI
    // -------------------------------------------------------------------------
    Rectangle {
        id: searchBar
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: Constants.innerPadding }
        height: Constants.barHeight + Constants.innerPadding
        radius: Constants.radius
        color: Constants.nord2

        IconImage {
            id: searchIcon
            anchors { left: parent.left; leftMargin: Constants.innerPadding; verticalCenter: parent.verticalCenter }
            source: Quickshell.iconPath("nix-snowflake", true)
            implicitSize: 24
        }

        TextInput {
            id: searchField
            anchors { left: searchIcon.right; leftMargin: Constants.innerPadding; right: parent.right; rightMargin: Constants.innerPadding; verticalCenter: parent.verticalCenter }
            color: Constants.nord6
            font.family: Constants.font.family
            font.pointSize: Constants.font.normalSize
            cursorVisible: activeFocus
            selectionColor: Constants.nord8
            selectedTextColor: Constants.nord0
            clip: true

            Text { anchors.fill: parent; text: "Search applications…"; color: Constants.nord3; font: parent.font; visible: parent.text.length === 0; renderType: Text.NativeRendering }

            Text {
                x: parent.cursorRectangle.x; height: parent.height; verticalAlignment: Text.AlignVCenter
                text: root.suggestion; color: Constants.nord4; opacity: 0.5; font: parent.font
                visible: root.suggestion.length > 0 && parent.cursorPosition === parent.text.length && parent.selectionStart === parent.selectionEnd
                renderType: Text.NativeRendering
            }

            onTextChanged: root.updateEntries()
            Keys.onEscapePressed: event => { DashboardState.close() }
            Keys.onTabPressed: event => {
                if (root.suggestion.length > 0) { const c = text + root.suggestion; text = c; cursorPosition = c.length }
                event.accepted = true
            }
            Keys.onUpPressed: event => {
                if (root.entries.length > 0) { root.selectedIndex = (root.selectedIndex - 1 + root.entries.length) % root.entries.length; appList.positionViewAtIndex(root.selectedIndex, ListView.Contain) }
                event.accepted = true
            }
            Keys.onDownPressed: event => {
                if (root.entries.length > 0) { root.selectedIndex = (root.selectedIndex + 1) % root.entries.length; appList.positionViewAtIndex(root.selectedIndex, ListView.Contain) }
                event.accepted = true
            }
            Keys.onReturnPressed: event => { root.launchSelected() }
            Keys.onEnterPressed:  event => { root.launchSelected() }
        }
    }

    Rectangle {
        id: divider
        anchors { top: searchBar.bottom; left: parent.left; right: parent.right; leftMargin: Constants.innerPadding; rightMargin: Constants.innerPadding }
        height: 1; color: Constants.nord3; opacity: 0.45
    }

    ListView {
        id: appList
        anchors { top: divider.bottom; topMargin: Constants.innerPadding / 2; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Constants.innerPadding / 2; rightMargin: Constants.innerPadding / 2; bottomMargin: Constants.innerPadding / 2 }
        clip: true; model: root.entries; currentIndex: root.selectedIndex
        acceptedButtons: Qt.NoButton
        HoverHandler { onPointChanged: root._trackMouse = true }

        delegate: AppItem {
            required property var modelData
            required property int index
            width: appList.width
            entry: modelData
            selected: root.selectedIndex === index
            onHovered: if (root._trackMouse) root.selectedIndex = index
            onLaunched: DashboardState.close()
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Constants.nord3; opacity: 0.6 }
        }
    }
}
