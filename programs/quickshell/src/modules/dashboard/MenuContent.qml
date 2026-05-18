pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import qs.modules.panels

Item {
    id: root

    PwObjectTracker { objects: Pipewire.nodes.values ?? [] }

    // ── Brightness ──────────────────────────────────────────────────────────
    property int brightness: 50
    property int maxBrightness: 100
    property string _backlightDev: ""

    Process {
        id: brReadProc
        command: ["bash", "-c", "d=$(ls /sys/class/backlight/ | head -1); echo $d $(cat /sys/class/backlight/$d/brightness) $(cat /sys/class/backlight/$d/max_brightness)"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length >= 3) {
                    root._backlightDev  = parts[0]
                    root.brightness     = parseInt(parts[1]) || 50
                    root.maxBrightness  = parseInt(parts[2]) || 100
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process { id: brSetProc }

    function setBrightness(value: int) {
        if (!root._backlightDev) return
        const clamped = Math.max(0, Math.min(root.maxBrightness, value))
        root.brightness = clamped
        brSetProc.command = [
            "busctl", "call",
            "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session",
            "SetBrightness", "ssu",
            "backlight", root._backlightDev, clamped
        ]
        brSetProc.running = true
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: Constants.innerPadding * 2 }
        spacing: Constants.innerPadding * 2

        // Brightness section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            Text {
                text: "󰃟  Brightness"
                color: Constants.nord4; font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.innerPadding

                Text { text: "󰃞"; color: Constants.nord3; font.family: Constants.font.family; font.pointSize: Constants.font.iconSize; renderType: Text.NativeRendering }

                // Slider track
                Rectangle {
                    id: brTrack
                    Layout.fillWidth: true; height: 8; radius: 4; color: Constants.nord2

                    Rectangle {
                        width: brTrack.width * (root.brightness / Math.max(root.maxBrightness, 1))
                        height: parent.height; radius: parent.radius; color: Constants.nord13
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeHorCursor
                        preventStealing: true
                        onClicked: mouse => root.setBrightness(Math.round(Math.max(0, Math.min(1, mouse.x / brTrack.width)) * root.maxBrightness))
                        onPositionChanged: mouse => {
                            if (pressed)
                                root.setBrightness(Math.round(Math.max(0, Math.min(1, mouse.x / brTrack.width)) * root.maxBrightness))
                        }
                    }

                    Rectangle {
                        width: 16; height: 16; radius: 8
                        x: Math.max(0, Math.min(brTrack.width - width, brTrack.width * (root.brightness / Math.max(root.maxBrightness, 1)) - width / 2))
                        y: (brTrack.height - height) / 2
                        color: brHandleMA.pressed ? Constants.nord8 : Constants.nord6
                        border.color: brHandleMA.pressed ? Constants.nord8 : Constants.nord3
                        border.width: 1
                        Behavior on color { CAnim {} }
                        Behavior on border.color { CAnim {} }

                        MouseArea {
                            id: brHandleMA
                            anchors.fill: parent
                            cursorShape: Qt.SizeHorCursor
                            preventStealing: true
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    const pt = mapToItem(brTrack, mouse.x, mouse.y)
                                    root.setBrightness(Math.round(Math.max(0, Math.min(1, pt.x / brTrack.width)) * root.maxBrightness))
                                }
                            }
                        }
                    }
                }

                Text { text: "󰃠"; color: Constants.nord13; font.family: Constants.font.family; font.pointSize: Constants.font.iconSize; renderType: Text.NativeRendering }

                Text {
                    text: Math.round(root.brightness / Math.max(root.maxBrightness, 1) * 100) + "%"
                    color: Constants.nord6; font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                    Layout.minimumWidth: 40
                }
            }

            // Presets
            RowLayout {
                Layout.fillWidth: true; spacing: 4
                Repeater {
                    model: [10, 25, 50, 75, 100]
                    PanelChip {
                        required property int modelData
                        label: modelData + "%"; icon: ""
                        active: Math.round(root.brightness / Math.max(root.maxBrightness, 1) * 100) === modelData
                        onToggled: root.setBrightness(Math.round(modelData / 100 * root.maxBrightness))
                    }
                }
            }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: Constants.nord3; opacity: 0.45 }

        // Audio output section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "󰽴  Audio Output"
                    color: Constants.nord4; font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "more →"
                    color: moreArea.containsMouse ? Constants.nord8 : Constants.nord3
                    font.family: Constants.font.family; font.pointSize: Constants.font.smallSize - 2
                    renderType: Text.NativeRendering
                    Behavior on color { CAnim {} }
                    MouseArea { id: moreArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DashboardState.switchTab("audio") }
                }
            }

            // Default sink volume
            AudioNodeRow {
                Layout.fillWidth: true
                node: Pipewire.defaultAudioSink
                isDefault: true
                onSetDefault: {}
                visible: Pipewire.defaultAudioSink !== null
            }
        }

        Item { Layout.fillHeight: true }
    }
}
