pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components
import qs.floweyshell 1.0

Item {
    id: root
    property int _devTab: 0

    ColumnLayout {
        anchors { fill: parent; margins: Constants.innerPadding * 2 }
        spacing: Constants.innerPadding * 2

        // System info header card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + Constants.innerPadding * 2
            radius: Constants.radius
            color: Constants.alpha(Constants.nord2, 0.5)

            RowLayout {
                id: headerRow
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: Constants.innerPadding * 2
                }
                spacing: Constants.innerPadding * 3

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "󱄅"
                        color: Constants.nord8
                        font.family: Constants.font.family
                        font.pointSize: 40
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: HwProvider.hostname
                        color: Constants.nord6; font.family: Constants.font.family
                        font.pointSize: Constants.font.normalSize; font.bold: true
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: "NixOS"
                        color: Constants.nord9; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                    }
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: Constants.nord3; opacity: 0.5 }

                GridLayout {
                    columns: 4
                    columnSpacing: Constants.innerPadding
                    rowSpacing: 6

                    Repeater {
                        model: [
                            { label: "Kernel", value: HwProvider.kernel },
                            { label: "Arch",   value: HwProvider.arch   },
                            { label: "CPU",    value: HwProvider.cpu    },
                            { label: "Uptime", value: HwProvider.uptime },
                        ]
                        delegate: RowLayout {
                            id: infoRow
                            required property var modelData
                            required property int index
                            Layout.column: (infoRow.index % 2) * 2
                            Layout.row: Math.floor(infoRow.index / 2)
                            spacing: 8

                            Text {
                                text: infoRow.modelData.label + ":"
                                color: Constants.nord8; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                renderType: Text.NativeRendering
                                Layout.minimumWidth: 55
                            }
                            Text {
                                text: infoRow.modelData.value
                                color: Constants.nord6; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                renderType: Text.NativeRendering
                                elide: Text.ElideRight
                                Layout.maximumWidth: 200
                            }
                        }
                    }
                }
            }
        }

        // Device tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: ["PCI Devices", "USB Devices"]
                delegate: ChipButton {
                    required property string modelData
                    required property int index
                    Layout.preferredWidth: 120
                    label: modelData
                    active: root._devTab === index
                    onClicked: root._devTab = index
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: (root._devTab === 0 ? HwProvider.pciDevices.length : HwProvider.usbDevices.length) + " devices"
                color: Constants.nord3; font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize - 2
                renderType: Text.NativeRendering
            }
        }

        // Device list
        ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            acceptedButtons: Qt.NoButton
            model: root._devTab === 0 ? HwProvider.pciDevices : HwProvider.usbDevices

            delegate: Rectangle {
                id: devDelegate
                required property var modelData
                required property int index
                width: deviceList.width
                height: 28
                radius: 4
                color: devDelegate.index % 2 === 0 ? "transparent" : Constants.alpha(Constants.nord2, 0.3)

                readonly property int treeIndent: (devDelegate.modelData.depth ?? 0) * 16

                // PCI row
                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: devDelegate.treeIndent + 8; rightMargin: 8
                    }
                    spacing: Constants.innerPadding
                    visible: root._devTab === 0

                    Text {
                        text: devDelegate.modelData.slot ?? ""
                        color: Constants.nord3; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 2
                        renderType: Text.NativeRendering
                        Layout.minimumWidth: 80
                    }
                    Text {
                        Layout.fillWidth: true
                        text: devDelegate.modelData.name ?? ""
                        color: Constants.nord6; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                    Text {
                        text: devDelegate.modelData.drv ?? ""
                        color: Constants.nord3; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 2
                        renderType: Text.NativeRendering
                        Layout.minimumWidth: 80
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // USB row
                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: devDelegate.treeIndent + 8; rightMargin: 8
                    }
                    spacing: Constants.innerPadding
                    visible: root._devTab === 1

                    readonly property bool hub: devDelegate.modelData.isHub ?? false

                    Text {
                        text: devDelegate.modelData.speed ?? ""
                        color: parent.hub ? Constants.nord9 : Constants.nord3
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 2
                        renderType: Text.NativeRendering
                        Layout.minimumWidth: 100
                    }
                    Text {
                        Layout.fillWidth: true
                        text: devDelegate.modelData.name ?? ""
                        color: parent.hub ? Constants.nord9 : Constants.nord6
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        font.italic: parent.hub
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                }
            }

            ScrollBar.vertical: StyledScrollBar {}
        }
    }
}
