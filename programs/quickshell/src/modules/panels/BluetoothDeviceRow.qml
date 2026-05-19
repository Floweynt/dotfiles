pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Rectangle {
    id: root

    required property BluetoothDevice device

    implicitHeight: col.implicitHeight + Constants.innerPadding * 2
    radius: Constants.radius
    color: Constants.alpha(Constants.nord2, 0.5)

    readonly property bool isConnected: device?.state === BluetoothDeviceState.Connected
    readonly property bool isConnecting: device?.state === BluetoothDeviceState.Connecting
                                      || device?.state === BluetoothDeviceState.Disconnecting
    readonly property bool isPairing: device?.pairing ?? false

    ColumnLayout {
        id: col
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            margins: Constants.innerPadding
        }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            // Device icon
            Text {
                text: {
                    const ic = root.device?.icon ?? ""
                    if (ic.includes("headphone") || ic.includes("headset")) return "󰋋"
                    if (ic.includes("phone")) return "󰄜"
                    if (ic.includes("keyboard")) return "󰌌"
                    if (ic.includes("mouse")) return "󰍽"
                    if (ic.includes("audio") || ic.includes("speaker")) return "󰓃"
                    return "󰂯"
                }
                color: root.isConnected ? Constants.nord8 : Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.iconSize
                renderType: Text.NativeRendering
                Behavior on color { CAnim {} }
            }

            Column {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.device?.name || root.device?.deviceName || ""
                    color: Constants.nord6
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize
                    renderType: Text.NativeRendering
                }
                Text {
                    text: root.isConnecting ? "connecting..."
                        : root.isPairing   ? "pairing..."
                        : root.isConnected ? "connected"
                        : root.device?.paired ? root.device.address
                        : "not paired  " + (root.device?.address ?? "")
                    color: root.isConnected ? Constants.nord14 : Constants.nord3
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize - 2
                    renderType: Text.NativeRendering
                    Behavior on color { CAnim {} }
                }
            }

            // Battery (if available)
            Text {
                visible: root.device?.batteryAvailable ?? false
                text: Math.round((root.device?.battery ?? 0) * 100) + "%"
                color: {
                    const b = root.device?.battery ?? 0
                    return b < 0.15 ? Constants.nord11 : b < 0.3 ? Constants.nord13 : Constants.nord4
                }
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize - 2
                renderType: Text.NativeRendering
            }
        }

        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: !root.isConnecting && !root.isPairing

            // Connect / Disconnect
            ChipButton {
                visible: root.device?.paired ?? false
                label: root.isConnected ? "Disconnect" : "Connect"
                icon: root.isConnected ? "󰂲" : "󰂱"
                active: root.isConnected
                onToggled: root.isConnected ? root.device.disconnect() : root.device.connect()
            }

            // Pair / Cancel pair
            ChipButton {
                visible: !(root.device?.paired ?? true)
                label: "Pair"
                icon: "󰌺"
                active: false
                onToggled: root.device?.pair()
            }

            // Trust toggle
            ChipButton {
                label: root.device?.trusted ?? false ? "Trusted" : "Trust"
                icon: "󰒃"
                active: root.device?.trusted ?? false
                onToggled: { if (root.device) root.device.trusted = !root.device.trusted }
            }

            // Forget
            ChipButton {
                visible: root.device?.paired ?? false
                label: "Forget"
                icon: "󰆴"
                active: false
                onToggled: root.device?.forget()
            }

            Item { Layout.fillWidth: true }
        }

        // Pairing / connecting progress
        Text {
            visible: root.isConnecting || root.isPairing
            Layout.fillWidth: true
            text: root.isPairing ? "Pairing in progress..." : root.isConnected ? "Disconnecting..." : "Connecting..."
            color: Constants.nord13
            font.family: Constants.font.family
            font.pointSize: Constants.font.smallSize - 2
            renderType: Text.NativeRendering
        }
    }
}
