pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.components
import qs.sysmon 1.0

Item {
    id: root

    Component.onCompleted: NixGenProvider.refresh()

    property bool   _busy: false
    property string _pendingMsg: ""

    Process {
        id: opProc
        property string _stderr: ""
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => { opProc._stderr += data + "\n" }
        }
        onExited: function(exitCode, exitStatus) {
            root._busy = false
            const errTail = opProc._stderr.trim()
            const msg = exitCode === 0 ? root._pendingMsg
                : ("Operation failed (exit " + exitCode + ")" + (errTail ? ": " + errTail : ""))
            Notifs.send("floweyshell", "Nix", msg, "system-software-update")
            opProc._stderr = ""
            if (exitCode === 0) NixGenProvider.refresh()
        }
    }

    readonly property string _nixEnv:   "/run/current-system/sw/bin/nix-env"
    readonly property string _nixStore: "/run/current-system/sw/bin/nix-store"

    function _run(cmd, successMsg) {
        if (_busy) return
        _busy = true
        _pendingMsg = successMsg
        opProc.command = cmd
        opProc.running = true
    }

    // ── Inline chip button ────────────────────────────────────────────────────
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string icon:  ""
        property color  tint:  Constants.nord4
        property bool   busy:  false
        signal clicked()

        implicitWidth:  chipRow.implicitWidth + 16
        implicitHeight: 26
        radius:         Constants.radius
        opacity:        chip.busy ? 0.4 : 1.0
        color:          Qt.rgba(tint.r, tint.g, tint.b, 0.12)
        border.color:   Qt.rgba(tint.r, tint.g, tint.b, 0.35)
        border.width:   1
        scale:          1.0

        Behavior on scale   { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            Text { text: chip.icon;  color: chip.tint; font.family: Constants.font.family; font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering }
            Text { text: chip.label; color: chip.tint; font.family: Constants.font.family; font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering }
        }

        MouseArea {
            anchors.fill: parent
            enabled:      !chip.busy
            cursorShape:  Qt.PointingHandCursor
            onPressed:    chip.scale = 0.88
            onReleased:   chip.scale = 1.0
            onClicked:    chip.clicked()
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: Constants.innerPadding * 2 }
        spacing: Constants.innerPadding

        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            Text {
                text: "  NixOS Generations"
                color: Constants.nord8
                font.family: Constants.font.family
                font.pointSize: Constants.font.normalSize
                font.bold: true
                renderType: Text.NativeRendering
            }
            Text {
                text: NixGenProvider.generations.length + " total"
                color: Constants.nord3
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }

            Chip {
                label: "Refresh"; icon: "󰜉"; tint: Constants.nord4; busy: root._busy
                onClicked: NixGenProvider.refresh()
            }
            Chip {
                label: "Delete old gens"; icon: "󰃮"; tint: Constants.nord11; busy: root._busy
                onClicked: root._run(
                    ["pkexec", "/bin/sh", "-c",
                     root._nixEnv + " --delete-generations old --profile /nix/var/nix/profiles/system"],
                    "Old generations deleted")
            }
            Chip {
                label: "Run GC"; icon: "󰃮"; tint: Constants.nord12; busy: root._busy
                onClicked: root._run(
                    ["pkexec", "/bin/sh", "-c",
                     root._nixStore + " --gc"],
                    "Garbage collection complete")
            }
            Chip {
                label: "Repair store"; icon: "󰒃"; tint: Constants.nord13; busy: root._busy
                onClicked: root._run(
                    ["pkexec", "/bin/sh", "-c",
                     root._nixStore + " --verify --check-contents --repair"],
                    "Nix store repair complete")
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Constants.nord3; opacity: 0.45 }

        // Generations list
        ListView {
            id: genList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: NixGenProvider.generations
            acceptedButtons: Qt.NoButton

            delegate: Rectangle {
                id: genCard
                required property var modelData
                required property int index

                width:  genList.width
                height: cardContent.implicitHeight + Constants.innerPadding * 2
                radius: Constants.radius

                color: genCard.modelData.current
                    ? Qt.rgba(Constants.nord8.r, Constants.nord8.g, Constants.nord8.b, 0.10)
                    : Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.45)
                border.color: genCard.modelData.current
                    ? Qt.rgba(Constants.nord8.r, Constants.nord8.g, Constants.nord8.b, 0.35)
                    : "transparent"
                border.width: 1

                ColumnLayout {
                    id: cardContent
                    anchors {
                        top: parent.top; left: parent.left; right: parent.right
                        margins: Constants.innerPadding * 1.5
                    }
                    spacing: 5

                    // Row 1: number + badges + action buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text:  "Gen " + genCard.modelData.number
                            color: genCard.modelData.current ? Constants.nord8 : Constants.nord6
                            font.family: Constants.font.family; font.pointSize: Constants.font.normalSize
                            font.bold: true; renderType: Text.NativeRendering
                        }

                        Rectangle {
                            visible: genCard.modelData.current
                            implicitWidth: curText.implicitWidth + 10; implicitHeight: 18; radius: 3
                            color: Qt.rgba(Constants.nord8.r, Constants.nord8.g, Constants.nord8.b, 0.20)
                            border.color: Constants.nord8; border.width: 1
                            Text { id: curText; anchors.centerIn: parent; text: "CURRENT"; color: Constants.nord8
                                font.family: Constants.font.family; font.pointSize: Constants.font.smallSize - 2
                                font.bold: true; renderType: Text.NativeRendering }
                        }

                        Rectangle {
                            visible: genCard.modelData.booted
                            implicitWidth: bootText.implicitWidth + 10; implicitHeight: 18; radius: 3
                            color: Qt.rgba(Constants.nord14.r, Constants.nord14.g, Constants.nord14.b, 0.20)
                            border.color: Constants.nord14; border.width: 1
                            Text { id: bootText; anchors.centerIn: parent; text: "BOOTED"; color: Constants.nord14
                                font.family: Constants.font.family; font.pointSize: Constants.font.smallSize - 2
                                font.bold: true; renderType: Text.NativeRendering }
                        }

                        Item { Layout.fillWidth: true }

                        Chip {
                            visible: !genCard.modelData.current
                            label: "Switch to"; icon: ""; tint: Constants.nord8; busy: root._busy
                            onClicked: {
                                const n = genCard.modelData.number
                                root._run(
                                    ["pkexec", "/bin/sh", "-c",
                                     root._nixEnv + " --switch-generation " + n +
                                     " --profile /nix/var/nix/profiles/system && " +
                                     "/nix/var/nix/profiles/system/bin/switch-to-configuration switch"],
                                    "Switched to generation " + n)
                            }
                        }

                        Chip {
                            visible: !genCard.modelData.current
                            label: "Delete"; icon: "󰅙"; tint: Constants.nord11; busy: root._busy
                            onClicked: {
                                const n = genCard.modelData.number
                                root._run(
                                    ["pkexec", "/bin/sh", "-c",
                                     root._nixEnv + " --delete-generations " + String(n) +
                                     " --profile /nix/var/nix/profiles/system"],
                                    "Generation " + n + " deleted")
                            }
                        }
                    }

                    // Row 2: version · date · store hash
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.innerPadding

                        Text { text: genCard.modelData.nixosVersion; color: Constants.nord9
                            font.family: Constants.font.family; font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering }
                        Text { text: "·"; color: Constants.nord3
                            font.family: Constants.font.family; font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering }
                        Text { text: genCard.modelData.date; color: Constants.nord4
                            font.family: Constants.font.family; font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: genCard.modelData.storePath.replace("/nix/store/", "").slice(0, 16) + "…"
                            color: Constants.nord3; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 1; renderType: Text.NativeRendering
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Constants.nord3; opacity: 0.6 }
            }
        }
    }
}
