pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.components

Item {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.innerPadding
        spacing: Constants.innerPadding

        // Header controls
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            // Power toggle
            PanelChip {
                label: root.adapter?.enabled ?? false ? "On" : "Off"
                icon: root.adapter?.enabled ?? false ? "󰂯" : "󰂲"
                active: root.adapter?.enabled ?? false
                onToggled: { if (root.adapter) root.adapter.enabled = !root.adapter.enabled }
            }

            // Scan toggle
            PanelChip {
                label: root.adapter?.discovering ?? false ? "Stop Scan" : "Scan"
                icon: root.adapter?.discovering ?? false ? "󰑖" : "󰐳"
                active: root.adapter?.discovering ?? false
                onToggled: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering }
            }

            Item { Layout.fillWidth: true }

            // Pairable toggle
            PanelChip {
                label: "Pairable"
                icon: "󰌺"
                active: root.adapter?.pairable ?? false
                onToggled: { if (root.adapter) root.adapter.pairable = !root.adapter.pairable }
            }
        }

        // Device list
        ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            acceptedButtons: Qt.NoButton

            model: Bluetooth.devices

            delegate: BluetoothDeviceRow {
                required property BluetoothDevice modelData
                device: modelData
                width: deviceList.width
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Constants.nord3; opacity: 0.6 }
            }
        }
    }
}
