pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.components
import qs.modules.panels

PanelWindow {
    id: root

    WlrLayershell.namespace: `${Constants.name}-dashboard`
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: DashboardState.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    color: "transparent"
    visible: DashboardState.visible

    anchors { top: true; bottom: true; left: true; right: true }

    GlobalShortcut { appid: Constants.name; name: "launcher";  onPressed: DashboardState.toggle("apps") }
    GlobalShortcut { appid: Constants.name; name: "dashboard"; onPressed: DashboardState.toggle("home") }

    property bool _shown: false

    Timer {
        id: showTimer; interval: 16
        onTriggered: { root._shown = true; root._focusContent() }
    }

    Connections {
        target: DashboardState
        function onVisibleChanged() {
            if (DashboardState.visible) { root._shown = false; showTimer.start() }
            else root._shown = false
        }
        function onTabChanged() { root._focusContent() }
    }

    function _focusContent() {
        if (DashboardState.tab === "apps") appsLoader.item?.focusSearch()
        else card.forceActiveFocus()
    }

    // id, label, keyIdx (which char is the accelerator), shortcut letter
    readonly property var tabs: [
        { id: "apps",      label: "Apps",      keyIdx: 0, key: "A" },
        { id: "home",      label: "Home",      keyIdx: 0, key: "H" },
        { id: "audio",     label: "Audio",     keyIdx: 1, key: "U" },
        { id: "net",       label: "Net",       keyIdx: 0, key: "N" },
        { id: "bluetooth", label: "Bluetooth", keyIdx: 0, key: "B" },
        { id: "perf",      label: "Perf",      keyIdx: 0, key: "P" },
        { id: "procs",     label: "Procs",     keyIdx: 1, key: "R" },
        { id: "sys",       label: "Sys",       keyIdx: 0, key: "S" },
        { id: "gen",       label: "Gen",       keyIdx: 0, key: "G" },
    ]

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Constants.nord0
        opacity: root._shown ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.standard } }
        MouseArea { anchors.fill: parent; onClicked: DashboardState.close() }
    }

    // Main card
    BarRect {
        id: card
        anchors.centerIn: parent
        width: parent.width * 0.78
        height: parent.height * 0.80
        color: Constants.nord1
        opacity: root._shown ? 1 : 0
        scale: root._shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.emphasizedDecel } }
        Behavior on scale   { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.emphasizedDecel } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowBlur: 0.5; shadowColor: "#000000"
            shadowOpacity: 0.6; shadowVerticalOffset: 12
        }

        // Absorb clicks so they don't fall through to the backdrop
        MouseArea { anchors.fill: parent }

        // Tab bar (top strip, same dark tone as old sidebar)
        Rectangle {
            id: tabBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 52
            color: Constants.nord0
            radius: Constants.radius

            // Clip bottom corners square so it butts up against the content
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: parent.radius
                color: parent.color
            }

            Row {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Constants.innerPadding; rightMargin: Constants.innerPadding
                }
                spacing: 4

                Repeater {
                    model: root.tabs
                    delegate: Rectangle {
                        id: tabBtn
                        required property var modelData
                        required property int index

                        readonly property bool active: DashboardState.tab === tabBtn.modelData.id

                        height: 30
                        width: tabRow.implicitWidth + Constants.innerPadding * 3
                        radius: height / 2

                        color: Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b,
                            tabBtn.active ? 0.9 : tabHover.containsMouse ? 0.4 : 0)
                        Behavior on color { CAnim {} }

                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 0

                            // text before accelerator char
                            Text {
                                text: tabBtn.modelData.label.slice(0, tabBtn.modelData.keyIdx)
                                color: tabBtn.active ? Constants.nord6 : Constants.nord4
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                renderType: Text.NativeRendering
                                Behavior on color { CAnim {} }
                            }
                            // accelerator char – underlined, always highlighted
                            Text {
                                text: tabBtn.modelData.label[tabBtn.modelData.keyIdx]
                                color: tabBtn.active ? Constants.nord8 : Constants.nord9
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                font.underline: true
                                renderType: Text.NativeRendering
                                Behavior on color { CAnim {} }
                            }
                            // text after accelerator char
                            Text {
                                text: tabBtn.modelData.label.slice(tabBtn.modelData.keyIdx + 1)
                                color: tabBtn.active ? Constants.nord6 : Constants.nord4
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                renderType: Text.NativeRendering
                                Behavior on color { CAnim {} }
                            }
                        }

                        MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DashboardState.switchTab(tabBtn.modelData.id)
                        }
                    }
                }
            }
        }

        // Divider between tab bar and content
        Rectangle {
            anchors { top: tabBar.bottom; left: parent.left; right: parent.right }
            height: 1; color: Constants.nord3; opacity: 0.3
        }

        // Content area – loaders stay alive once created to avoid flicker on re-entry
        Item {
            anchors { top: tabBar.bottom; topMargin: 1; left: parent.left; right: parent.right; bottom: parent.bottom }

            Loader { id: appsLoader;  anchors.fill: parent; active: DashboardState.tab === "apps"      || status === Loader.Ready; visible: DashboardState.tab === "apps";      opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: appsComp }
            Loader { id: homeLoader;  anchors.fill: parent; active: DashboardState.tab === "home"      || status === Loader.Ready; visible: DashboardState.tab === "home";      opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: homeComp }
            Loader { id: audioLoader; anchors.fill: parent; active: DashboardState.tab === "audio"     || status === Loader.Ready; visible: DashboardState.tab === "audio";     opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: audioComp }
            Loader { id: netLoader;   anchors.fill: parent; active: DashboardState.tab === "net"       || status === Loader.Ready; visible: DashboardState.tab === "net";       opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: netComp }
            Loader { id: btLoader;    anchors.fill: parent; active: DashboardState.tab === "bluetooth" || status === Loader.Ready; visible: DashboardState.tab === "bluetooth"; opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: btComp }
            Loader { id: perfLoader;  anchors.fill: parent; active: DashboardState.tab === "perf"      || status === Loader.Ready; visible: DashboardState.tab === "perf";      opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: perfComp }
            Loader { id: procsLoader; anchors.fill: parent; active: DashboardState.tab === "procs"     || status === Loader.Ready; visible: DashboardState.tab === "procs";     opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: procsComp }
            Loader { id: sysLoader;   anchors.fill: parent; active: DashboardState.tab === "sys"       || status === Loader.Ready; visible: DashboardState.tab === "sys";       opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: sysComp }
            Loader { id: genLoader;   anchors.fill: parent; active: DashboardState.tab === "gen"       || status === Loader.Ready; visible: DashboardState.tab === "gen";       opacity: visible ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } sourceComponent: genComp }
        }

        Component { id: appsComp;  AppsContent      {} }
        Component { id: homeComp;  HomeContent      {} }
        Component { id: audioComp; AudioContent     {} }
        Component { id: netComp;   NetworkContent   {} }
        Component { id: btComp;    BluetoothContent {} }
        Component { id: perfComp;  PerfContent      {} }
        Component { id: procsComp; ProcsContent     {} }
        Component { id: sysComp;   SysContent       {} }
        Component { id: genComp;   NixGenContent    {} }
    }

    function _navTab(delta) {
        const n   = root.tabs.length
        const idx = root.tabs.findIndex(t => t.id === DashboardState.tab)
        DashboardState.switchTab(root.tabs[(idx + delta + n) % n].id)
    }

    // Esc always closes regardless of which child has focus
    Shortcut { sequence: "Escape"; onActivated: DashboardState.close() }

    // Tab cycle navigation (Alt so it works from any context including the app launcher)
    Shortcut { sequence: "Alt+Right";     onActivated: if (DashboardState.visible) root._navTab(+1) }
    Shortcut { sequence: "Alt+Left";      onActivated: if (DashboardState.visible) root._navTab(-1) }
    Shortcut { sequence: "Alt+Tab";       onActivated: if (DashboardState.visible) root._navTab(+1) }
    Shortcut { sequence: "Alt+Shift+Tab"; onActivated: if (DashboardState.visible) root._navTab(-1) }

    // Alt+accelerator tab switching
    Shortcut { sequence: "Alt+A"; onActivated: if (DashboardState.visible) DashboardState.switchTab("apps") }
    Shortcut { sequence: "Alt+H"; onActivated: if (DashboardState.visible) DashboardState.switchTab("home") }
    Shortcut { sequence: "Alt+U"; onActivated: if (DashboardState.visible) DashboardState.switchTab("audio") }
    Shortcut { sequence: "Alt+N"; onActivated: if (DashboardState.visible) DashboardState.switchTab("net") }
    Shortcut { sequence: "Alt+B"; onActivated: if (DashboardState.visible) DashboardState.switchTab("bluetooth") }
    Shortcut { sequence: "Alt+P"; onActivated: if (DashboardState.visible) DashboardState.switchTab("perf") }
    Shortcut { sequence: "Alt+R"; onActivated: if (DashboardState.visible) DashboardState.switchTab("procs") }
    Shortcut { sequence: "Alt+S"; onActivated: if (DashboardState.visible) DashboardState.switchTab("sys") }
    Shortcut { sequence: "Alt+G"; onActivated: if (DashboardState.visible) DashboardState.switchTab("gen") }
}
