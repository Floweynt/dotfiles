pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs
import qs.services
import qs.components

PanelWindow {
    id: root

    WlrLayershell.namespace: `${Constants.name}-launcher`
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: LauncherState.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    color: "transparent"
    visible: LauncherState.visible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Bound via Hyprland: bind = $mainMod, p, global, floweyshell:launcher
    GlobalShortcut {
        appid: Constants.name
        name: "launcher"
        onPressed: LauncherState.toggle()
    }

    property var entries: []
    property int selectedIndex: 0
    property bool _shown: false
    property var pathExecutables: []
    property var _pathBuf: []
    property string _deferredCmd: ""

    // Fires a shell command after the launcher has fully dismissed
    Timer {
        id: deferredTimer
        interval: 250
        onTriggered: {
            if (root._deferredCmd) {
                cliProcess.command = ["bash", "-c", root._deferredCmd]
                cliProcess.startDetached()
                root._deferredCmd = ""
            }
        }
    }

    // Pre-load all executables from PATH once at startup
    Process {
        id: pathLoader
        command: ["bash", "-c", "compgen -c | sort -u"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim()
                if (line) root._pathBuf.push(line)
            }
        }
        Component.onCompleted: running = true
        onExited: {
            root.pathExecutables = root._pathBuf
            root._pathBuf = []
        }
    }

    Process { id: cliProcess }

    Connections {
        target: ProxyState
        function onActiveChanged() { if (LauncherState.visible) root.updateEntries() }
    }

    // ---------------------------------------------------------------------------
    // Subcommand infrastructure helpers
    // ---------------------------------------------------------------------------

    // Returns entries for commands that declare a subcommands array.
    // args is the raw string after the command name (may be partial/empty).
    function resolveSubcommandEntries(subcommands, args) {
        const lc = args.toLowerCase().trim()
        const filtered = lc
            ? subcommands.filter(s => s.name.startsWith(lc))
            : subcommands
        return filtered.map(s => ({
            name: s.name, iconName: "", iconGlyph: s.icon ?? "",
            categories: [], description: s.description ?? "",
            keepOpen: false,
            run: s.run
        }))
    }

    // Returns autocomplete suffix for a subcommand name.
    function resolveSubcommandSuggestion(subcommands, args) {
        if (!args) return ""
        const match = subcommands.find(s => s.name.startsWith(args) && s.name !== args)
        return match ? match.name.slice(args.length) : ""
    }

    // Evaluates description which may be a string or a no-arg function.
    function cmdDesc(cmd) {
        return typeof cmd.description === "function" ? cmd.description() : (cmd.description ?? "")
    }

    // ---------------------------------------------------------------------------
    // Command registry — add new commands here only.
    //
    // Schema:
    //   { name, description (string|fn), icon }
    //   + one of:
    //     subcommands: [{ name, description, icon, run() }]   — routed generically
    //     run()                                               — single-action command
    //   (or neither, for custom-routed commands like /cli)
    // ---------------------------------------------------------------------------
    readonly property var commandRegistry: [
        {
            name: "cli",
            description: "Run a shell command",
            icon: ""
        },
        {
            name: "screenshot",
            description: "Take a screenshot",
            icon: "",
            subcommands: [
                { name: "area",   description: "Select a region",        icon: "",
                  run: () => { root._deferredCmd = "mkdir -p /tmp/screenshots && grimblast --notify copysave area /tmp/screenshots/" } },
                { name: "screen", description: "Capture full screen",    icon: "",
                  run: () => { root._deferredCmd = "mkdir -p /tmp/screenshots && grimblast --notify copysave screen /tmp/screenshots/" } },
                { name: "active", description: "Capture active window",  icon: "",
                  run: () => { root._deferredCmd = "mkdir -p /tmp/screenshots && grimblast --notify copysave active /tmp/screenshots/" } },
            ]
        },
        {
            name: "proxy",
            description: () => ProxyState.active ? "Proxy: active" : "Proxy: inactive",
            icon: "󰖟",
            subcommands: [
                { name: "start",   description: "Start the proxy",   icon: "",  run: () => ProxyState.start()   },
                { name: "stop",    description: "Stop the proxy",    icon: "󰅙",  run: () => ProxyState.stop()    },
                { name: "restart", description: "Restart the proxy", icon: "󰜉", run: () => ProxyState.restart() },
            ]
        },
        {
            name: "update",
            description: "Rebuild NixOS flake",
            icon: "󱄅",
            run: () => {
                cliProcess.command = ["kitty", "--", "bash", "-c",
                    "sudo nixos-rebuild switch --flake /persist/@home/dotfiles#nix-fw16; echo; read -p 'Press Enter to close...'"]
                cliProcess.startDetached()
            }
        },
        {
            name: "suspend",
            description: "Suspend the system",
            icon: "󰒲",
            run: () => {
                cliProcess.command = ["systemctl", "suspend"]
                cliProcess.startDetached()
            }
        },
        {
            name: "reboot",
            description: "Reboot the system",
            icon: "󰜉",
            run: () => {
                cliProcess.command = ["systemctl", "reboot"]
                cliProcess.startDetached()
            }
        },
        {
            name: "search",
            description: "Search the web",
            icon: "󰖟",
            argsHint: true
        },
        {
            name: "br",
            description: "Screen brightness",
            icon: "󰃟",
            argsHint: true
        },
        {
            name: "audio",
            description: "Audio devices & streams",
            icon: "󰽴",
            run: () => PanelState.open("audio")
        },
        {
            name: "net",
            description: "WiFi networks",
            icon: "󱋊",
            run: () => PanelState.open("net")
        },
        {
            name: "bluetooth",
            description: "Bluetooth devices",
            icon: "󰂯",
            run: () => PanelState.open("bluetooth")
        },
        {
            name: "nix",
            description: "Nix/NixOS tools",
            icon: "",
            subcommands: [
                { name: "gc",     description: "Collect garbage",                    icon: "󰃮",
                  run: () => { cliProcess.command = ["kitty", "--", "bash", "-c", "nix-collect-garbage -d; echo; read -p 'Press Enter to close...'"];     cliProcess.startDetached() } },
                { name: "repair", description: "Repair nix store",                  icon: "󰒔",
                  run: () => { cliProcess.command = ["kitty", "--", "bash", "-c", "sudo nix store repair; echo; read -p 'Press Enter to close...'"];       cliProcess.startDetached() } },
                { name: "gen",    description: "List NixOS generations",             icon: "󱚢",
                  run: () => { cliProcess.command = ["kitty", "--", "bash", "-c", "nixos-rebuild list-generations; echo; read -p 'Press Enter to close...'"];    cliProcess.startDetached() } },
            ]
        }
    ]

    // ---------------------------------------------------------------------------
    // Command routing
    // ---------------------------------------------------------------------------

    function getCommandEntries(name, args) {
        // /cli — free-form shell command
        if (name === "cli") {
            const cmd = args.trim()
            return [{
                name: cmd ? "Run: " + cmd : "Run Command",
                iconName: "", iconGlyph: "",
                categories: ["TerminalEmulator"],
                description: cmd ? "" : "Type /cli <command> to run a shell command",
                keepOpen: !cmd,
                run: () => {
                    if (cmd) {
                        cliProcess.command = ["sh", "-c", cmd]
                        cliProcess.startDetached()
                    } else {
                        searchField.text = "/cli "
                        searchField.cursorPosition = 5
                    }
                }
            }]
        }

        // /search — web search via default browser
        if (name === "search") {
            const query = args.trim()
            return [{
                name: query ? "Search: " + query : "Web Search",
                iconName: "", iconGlyph: "󰖟",
                categories: ["WebBrowser"],
                description: query ? "duckduckgo.com" : "Type /search <query>",
                keepOpen: !query,
                run: () => {
                    if (query) {
                        const url = "https://duckduckgo.com/?q=" + encodeURIComponent(query)
                        cliProcess.command = ["librewolf", "--new-tab", url]
                        cliProcess.startDetached()
                    } else {
                        searchField.text = "/search "
                        searchField.cursorPosition = 8
                    }
                }
            }]
        }

        // /br — screen brightness
        if (name === "br") {
            const arg = args.trim()

            function brEntry(label, desc, setValue) {
                return {
                    name: label, iconName: "", iconGlyph: "󰃟",
                    categories: [], description: desc,
                    keepOpen: false,
                    run: () => {
                        cliProcess.command = ["brightnessctl", "set", setValue]
                        cliProcess.startDetached()
                    }
                }
            }

            if (arg) {
                let setValue
                if (arg.startsWith("+"))      setValue = "+" + arg.slice(1).replace(/%$/, "") + "%"
                else if (arg.startsWith("-")) setValue = arg.slice(1).replace(/%$/, "") + "%-"
                else                          setValue = arg.replace(/%$/, "") + "%"
                return [brEntry("Set brightness: " + arg, "", setValue)]
            }

            return [
                brEntry("10%",  "Set brightness to 10%",  "10%"),
                brEntry("25%",  "Set brightness to 25%",  "25%"),
                brEntry("50%",  "Set brightness to 50%",  "50%"),
                brEntry("75%",  "Set brightness to 75%",  "75%"),
                brEntry("100%", "Set brightness to 100%", "100%"),
            ]
        }

const reg = commandRegistry.find(c => c.name === name)
        if (!reg) return []

        // Commands with subcommands — generic routing
        if (reg.subcommands) return resolveSubcommandEntries(reg.subcommands, args)

        // Single-action commands
        if (reg.run) {
            return [{
                name: reg.name, iconName: "", iconGlyph: reg.icon ?? "",
                categories: [], description: cmdDesc(reg),
                keepOpen: false,
                run: reg.run
            }]
        }

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

    // ---------------------------------------------------------------------------
    // Ghost autocomplete text (remaining chars after cursor)
    // ---------------------------------------------------------------------------
    property string suggestion: {
        const text = searchField.text
        if (!text) return ""

        if (text.startsWith("/")) {
            const partial = text.slice(1)
            const active = commandRegistry.find(
                c => partial === c.name || partial.startsWith(c.name + " "))
            if (active) {
                const args = partial.startsWith(active.name + " ")
                    ? partial.slice(active.name.length + 1) : ""
                return getCommandSuggestion(active.name, args)
            }
            if (partial && !partial.includes(" ")) {
                const match = commandRegistry.find(
                    c => c.name.startsWith(partial) && c.name !== partial)
                if (match) return match.name.slice(partial.length)
            }
            return ""
        }

        const first = entries.find(e => !e._isCommand)
        if (first && first.name.toLowerCase().startsWith(text.toLowerCase()))
            return first.name.slice(text.length)
        return ""
    }

    // ---------------------------------------------------------------------------
    // Entry builders
    // ---------------------------------------------------------------------------
    function buildEntry(e) {
        return {
            name: e.name,
            iconName: e.icon ?? "",
            categories: e.categories ?? [],
            description: e.genericName || e.comment || "",
            keepOpen: false,
            run: () => e.execute()
        }
    }

    function makeCommandEntry(cmd) {
        return {
            name: "/" + cmd.name,
            iconName: "", iconGlyph: cmd.icon,
            categories: [], description: cmdDesc(cmd),
            _isCommand: true, keepOpen: true,
            run: () => {
                searchField.text = "/" + cmd.name + (cmd.subcommands || cmd.argsHint ? " " : "")
                searchField.cursorPosition = searchField.text.length
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Entry update — resolves current mode from search text
    // ---------------------------------------------------------------------------
    function updateEntries() {
        const raw = searchField.text
        const query = raw.trim()

        if (query.startsWith("/")) {
            const partial = query.slice(1)

            const active = commandRegistry.find(
                c => partial === c.name || partial.startsWith(c.name + " "))
            if (active) {
                const args = partial.startsWith(active.name + " ")
                    ? partial.slice(active.name.length + 1) : ""
entries = getCommandEntries(active.name, args)
                selectedIndex = 0
                return
            }

            const lc = partial.toLowerCase()
            const cmds = lc
                ? commandRegistry.filter(c => c.name.startsWith(lc))
                : commandRegistry
            entries = cmds.map(c => makeCommandEntry(c))
            selectedIndex = 0
            return
        }

        const lq = query.toLowerCase()
        const apps = DesktopEntries.applications.values
        if (!apps) return
        const filtered = lq
            ? apps.filter(e =>
                e.name.toLowerCase().includes(lq) ||
                (e.keywords && e.keywords.some(k => k.toLowerCase().includes(lq))))
            : apps
        entries = [
            ...filtered.map(e => buildEntry(e)),
            ...commandRegistry.map(c => makeCommandEntry(c))
        ]
        selectedIndex = 0
    }

    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < entries.length) {
            const entry = entries[selectedIndex]
            entry.run()
            if (!entry.keepOpen) LauncherState.hide()
        }
    }

    // Reset and animate on open
    Timer {
        id: animTimer
        interval: 16
        onTriggered: {
            root._shown = true
            searchField.forceActiveFocus()
        }
    }

    Connections {
        target: LauncherState
        function onVisibleChanged() {
            if (LauncherState.visible) {
                root._shown = false
                searchField.text = ""
                root.updateEntries()
                animTimer.start()
            } else {
                root._shown = false
                if (root._deferredCmd) deferredTimer.start()
            }
        }
    }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Constants.nord0
        opacity: root._shown ? 0.82 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animDurations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Constants.animCurves.standard
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: LauncherState.hide()
        }
    }

    // Launcher card
    BarRect {
        id: card

        anchors.centerIn: parent

        width: parent.width * 0.5
        height: parent.height * 0.5

        color: Constants.nord1

        opacity: root._shown ? 1 : 0
        scale: root._shown ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animDurations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Constants.animCurves.emphasizedDecel
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Constants.animDurations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Constants.animCurves.emphasizedDecel
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.5
            shadowColor: "#000000"
            shadowOpacity: 0.55
            shadowVerticalOffset: 10
        }

        // Search bar
        Rectangle {
            id: searchBar

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Constants.innerPadding
            }

            height: Constants.barHeight + Constants.innerPadding
            radius: Constants.radius
            color: Constants.nord2

            IconImage {
                id: searchIcon
                anchors {
                    left: parent.left
                    leftMargin: Constants.innerPadding
                    verticalCenter: parent.verticalCenter
                }
                source: Quickshell.iconPath("nix-snowflake", true)
                implicitSize: 24
            }

            TextInput {
                id: searchField

                anchors {
                    left: searchIcon.right
                    leftMargin: Constants.innerPadding
                    right: parent.right
                    rightMargin: Constants.innerPadding
                    verticalCenter: parent.verticalCenter
                }

                color: Constants.nord6
                font.family: Constants.font.family
                font.pointSize: Constants.font.normalSize
                cursorVisible: activeFocus
                selectionColor: Constants.nord8
                selectedTextColor: Constants.nord0
                clip: true

                // Placeholder
                Text {
                    anchors.fill: parent
                    text: "Search applications..."
                    color: Constants.nord3
                    font: parent.font
                    visible: parent.text.length === 0
                    renderType: Text.NativeRendering
                }

                // Ghost autocomplete text
                Text {
                    x: parent.cursorRectangle.x
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: root.suggestion
                    color: Constants.nord4
                    opacity: 0.5
                    font: parent.font
                    visible: root.suggestion.length > 0
                              && parent.cursorPosition === parent.text.length
                              && parent.selectionStart === parent.selectionEnd
                    renderType: Text.NativeRendering
                }

                onTextChanged: root.updateEntries()

                Keys.onEscapePressed: event => { LauncherState.hide() }
                Keys.onTabPressed: event => {
                    if (root.suggestion.length > 0) {
                        const completed = text + root.suggestion
                        text = completed
                        cursorPosition = completed.length
                    }
                    event.accepted = true
                }
                Keys.onUpPressed: event => {
                    if (root.entries.length > 0) {
                        root.selectedIndex = (root.selectedIndex - 1 + root.entries.length) % root.entries.length
                        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    event.accepted = true
                }
                Keys.onDownPressed: event => {
                    if (root.entries.length > 0) {
                        root.selectedIndex = (root.selectedIndex + 1) % root.entries.length
                        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    event.accepted = true
                }
                Keys.onReturnPressed: event => { root.launchSelected() }
                Keys.onEnterPressed: event => { root.launchSelected() }
            }
        }

        // Divider
        Rectangle {
            id: divider
            anchors {
                top: searchBar.bottom
                left: parent.left
                right: parent.right
                leftMargin: Constants.innerPadding
                rightMargin: Constants.innerPadding
            }
            height: 1
            color: Constants.nord3
            opacity: 0.45
        }

        // App list
        ListView {
            id: appList

            anchors {
                top: divider.bottom
                topMargin: Constants.innerPadding / 2
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: Constants.innerPadding / 2
                rightMargin: Constants.innerPadding / 2
                bottomMargin: Constants.innerPadding / 2
            }

            clip: true
            model: root.entries
            currentIndex: root.selectedIndex

            delegate: AppItem {
                required property var modelData
                required property int index
                width: appList.width
                entry: modelData
                selected: root.selectedIndex === index
                onHovered: root.selectedIndex = index
                onLaunched: LauncherState.hide()
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Constants.nord3
                    opacity: 0.6
                }
            }
        }
    }
}
