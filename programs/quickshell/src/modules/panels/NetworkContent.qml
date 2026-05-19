pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.components

Item {
    id: root

    readonly property var wifiDev: {
        const devs = Networking.devices?.values ?? []
        for (const d of devs) {
            if (d.type === DeviceType.Wifi) return d
        }
        return null
    }

    readonly property var sortedNetworks: {
        const nets = root.wifiDev?.networks?.values ?? []
        return [...nets].sort((a, b) => {
            if (a.connected !== b.connected) return b.connected ? 1 : -1
            return b.signalStrength - a.signalStrength
        })
    }

    function securityLabel(sec) {
        if (sec === WifiSecurityType.Open || sec === WifiSecurityType.Unknown) return "open"
        if (sec === WifiSecurityType.Sae) return "WPA3"
        if (sec === WifiSecurityType.Wpa2Psk || sec === WifiSecurityType.WpaPsk) return "WPA2"
        if (sec === WifiSecurityType.Wpa2Eap || sec === WifiSecurityType.WpaEap) return "WPA-EAP"
        if (sec === WifiSecurityType.Owe) return "OWE"
        return "secured"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.innerPadding
        spacing: Constants.innerPadding

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.wifiDev === null ? "No WiFi device"
                    : root.sortedNetworks.length + " networks"
                color: Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            ChipButton {
                label: Networking.wifiEnabled ? "WiFi On" : "WiFi Off"
                icon: Networking.wifiEnabled ? "󰤨" : "󰤭"
                active: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            ChipButton {
                label: "Scan"
                icon: "󰑖"
                active: root.wifiDev?.scannerEnabled ?? false
                onToggled: {
                    if (root.wifiDev) {
                        root.wifiDev.scannerEnabled = true
                        scanOffTimer.restart()
                    }
                }
            }
        }

        Timer {
            id: scanOffTimer
            interval: 10000
            onTriggered: { if (root.wifiDev) root.wifiDev.scannerEnabled = false }
        }

        ListView {
            id: netList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            acceptedButtons: Qt.NoButton
            model: root.sortedNetworks

            delegate: Rectangle {
                id: netDelegate
                required property var modelData
                required property int index

                width: netList.width
                implicitHeight: netRow.implicitHeight + Constants.innerPadding * 2
                radius: Constants.radius
                color: netDelegate.modelData.connected
                    ? Constants.alpha(Constants.nord14, 0.15)
                    : Constants.alpha(Constants.nord2, 0.5)
                Behavior on color { CAnim {} }

                RowLayout {
                    id: netRow
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Constants.innerPadding
                    }
                    spacing: Constants.innerPadding

                    Text {
                        text: {
                            const s = netDelegate.modelData.signalStrength
                            return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟"
                        }
                        color: netDelegate.modelData.connected ? Constants.nord14 : Constants.nord4
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.iconSize
                        renderType: Text.NativeRendering
                        Behavior on color { CAnim {} }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            width: parent.width
                            text: netDelegate.modelData.name
                            color: netDelegate.modelData.connected ? Constants.nord14 : Constants.nord6
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                            Behavior on color { CAnim {} }
                        }
                        Text {
                            text: (netDelegate.modelData.connected ? "connected  " : "")
                                + Math.round(netDelegate.modelData.signalStrength * 100) + "%  "
                                + root.securityLabel(netDelegate.modelData.security)
                            color: netDelegate.modelData.connected ? Constants.nord14 : Constants.nord3
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2
                            renderType: Text.NativeRendering
                            Behavior on color { CAnim {} }
                        }
                    }

                    ChipButton {
                        label: netDelegate.modelData.connected ? "Disconnect" : "Connect"
                        icon:  netDelegate.modelData.connected ? "󰖪" : "󰖩"
                        active: netDelegate.modelData.connected
                        onToggled: netDelegate.modelData.connected
                            ? netDelegate.modelData.disconnect()
                            : netDelegate.modelData.connect()
                    }
                }
            }

            ScrollBar.vertical: StyledScrollBar {}
        }
    }
}
