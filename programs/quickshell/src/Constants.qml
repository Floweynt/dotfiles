pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Services.Notifications

Singleton {
    readonly property color nord0: "#2e3440"
    readonly property color nord1: "#3b4252"
    readonly property color nord2: "#434c5e"
    readonly property color nord3: "#4c566a"
    readonly property color nord4: "#d8dee9"
    readonly property color nord5: "#e5e9f0"
    readonly property color nord6: "#eceff4"
    readonly property color nord7: "#8fbcbb"
    readonly property color nord8: "#88c0d0"
    readonly property color nord9: "#81a1c1"
    readonly property color nord10: "#5e81ac"
    readonly property color nord11: "#bf616a"
    readonly property color nord12: "#d08770"
    readonly property color nord13: "#ebcb8b"
    readonly property color nord14: "#a3be8c"
    readonly property color nord15: "#b48ead"

    readonly property string name: "floweyshell"
    readonly property int outerPadding: 10
    readonly property int innerPadding: 7

    readonly property int topBarHeight: 55
    readonly property int barHeight: 40
    readonly property int radius: 10

    readonly property int notifBorderRadius: 3
    readonly property int notifAppIconHeight: 40

    property QtObject icons: QtObject {
        readonly property var categoryIcons: ({
                WebBrowser: "󰖟",
                Printing: "󰐪",
                Security: "󰒃",
                Network: "󱋊",
                Archiving: "󱈎",
                Compression: "󱈎",
                Development: "󰅪",
                IDE: "󰅪",
                TextEditor: "󱞂",
                Audio: "󰽴",
                Music: "󰽴",
                Player: "󰽴",
                Recorder: "󰍮",
                Game: "󰮃",
                FileTools: "󰪶",
                FileManager: "󰪶",
                Filesystem: "󰪶",
                FileTransfer: "󰪶",
                Settings: "",
                DesktopSettings: "",
                HardwareSettings: "",
                TerminalEmulator: "",
                ConsoleOnly: "",
                Utility: "󰯠",
                Monitor: "",
                Midi: "",
                Mixer: "",
                AudioVideoEditing: "",
                AudioVideo: "",
                Video: "",
                Building: "",
                Graphics: "",
                "2DGraphics": "",
                RasterGraphics: "",
                TV: "",
                System: "󰒋",
                Office: "󰆒"
            })

        readonly property string desktopIcon: "󰇄"

        function getAppIcon(name: string, fallback: string): string {
            const icon = DesktopEntries.heuristicLookup(name)?.icon;
            if (fallback !== "undefined")
                return Quickshell.iconPath(icon, fallback);
            return Quickshell.iconPath(icon);
        }

        function getAppCategoryIcon(name: string, fallback: string): string {
            const categories = DesktopEntries.heuristicLookup(name)?.categories;

            if (categories)
                for (const [key, value] of Object.entries(categoryIcons))
                    if (categories.includes(key))
                        return value;
            return fallback;
        }
    }

    // stolen
    function alpha(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a) }

    property QtObject animCurves: QtObject {
        property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    }

    property QtObject animDurations: QtObject {
        readonly property int normal: 400
    }

    property QtObject font: QtObject {
        readonly property string family: "JetBrainsMono Nerd Font Mono"
        readonly property int smallSize: 13
        readonly property int normalSize: 17
        readonly property int bigIconSize: 29
        readonly property int iconSize: 22
    }
}
