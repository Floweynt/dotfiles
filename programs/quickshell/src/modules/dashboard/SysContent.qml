pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components

Item {
    id: root

    property string sysHostname: "…"
    property string sysOS: "NixOS"
    property string sysKernel: "…"
    property string sysUptime: "…"
    property string sysCPU: "…"
    property string sysArch: "…"

    property var pciDevices: []
    property var usbDevices: []
    property int _devTab: 0

    // ── PCI state ──────────────────────────────────────────────────────────
    property var _pciV: ({})
    property var _pciD: ({})
    property var _pciQ: []
    property int _pciQi: 0
    property var _pciAcc: []
    property bool _pciScanDone: false

    // ── USB state ──────────────────────────────────────────────────────────
    property var _usbV: ({})
    property var _usbD: ({})
    property var _usbEvetQ: []
    property int _usbEvetQi: 0
    property var _usbValidDevs: []
    property var _usbSpdQ: []
    property int _usbSpdQi: 0
    property var _usbAcc: []
    property bool _usbScanDone: false

    function _parsePciIds(src) {
        const V = {}, D = {}
        let curVid = ""
        for (const ln of src.split('\n')) {
            if (ln.startsWith('#') || ln === '') continue
            if (/^[0-9a-fA-F]{4}  /.test(ln)) {
                curVid = ln.slice(0, 4).toLowerCase()
                V[curVid] = ln.slice(6).trim()
            } else if (curVid && /^\t[0-9a-fA-F]{4}  /.test(ln)) {
                D[curVid + ":" + ln.slice(1, 5).toLowerCase()] = ln.slice(7).trim()
            } else if (!/^\t/.test(ln)) {
                curVid = ""
            }
        }
        root._pciV = V
        root._pciD = D
    }

    function _parseUsbIds(src) {
        const V = {}, D = {}
        let curVid = ""
        for (const ln of src.split('\n')) {
            if (ln.startsWith('#') || ln === '') continue
            if (/^[0-9a-fA-F]{4}  /.test(ln)) {
                curVid = ln.slice(0, 4).toLowerCase()
                V[curVid] = ln.slice(6).trim()
            } else if (curVid && /^\t[0-9a-fA-F]{4}  /.test(ln)) {
                D[curVid + ":" + ln.slice(1, 5).toLowerCase()] = ln.slice(7).trim()
            } else if (!/^\t/.test(ln)) {
                curVid = ""
            }
        }
        root._usbV = V
        root._usbD = D
    }

    function _buildPci() {
        if (!root._pciScanDone) return
        root.pciDevices = root._pciAcc.map(dev => {
            const vn = root._pciV[dev.vid] ?? ""
            const dn = root._pciD[dev.vid + ":" + dev.did] ?? ""
            const name = vn && dn ? vn + " " + dn
                       : vn       ? vn + " [" + dev.did + "]"
                       :            dev.vid + ":" + dev.did
            return { slot: dev.slot, id: dev.vid + ":" + dev.did, drv: dev.drv, name }
        })
    }

    function _buildUsb() {
        if (!root._usbScanDone) return
        root.usbDevices = root._usbAcc.map(dev => {
            const vn = root._usbV[dev.vid] ?? ""
            const dn = root._usbD[dev.vid + ":" + dev.pid] ?? ""
            const name = [vn, dn].filter(Boolean).join(" ") || (dev.vid + ":" + dev.pid)
            return { id: dev.vid + ":" + dev.pid, name, spd: dev.spd }
        })
    }

    // ── Sysinfo readers ────────────────────────────────────────────────────
    FileView { path: "/proc/sys/kernel/hostname"; onLoaded: root.sysHostname = text().trim() }
    FileView { path: "/proc/sys/kernel/osrelease"; onLoaded: root.sysKernel = text().trim() }
    FileView {
        path: "/proc/uptime"
        onLoaded: {
            const s = parseFloat(text())
            root.sysUptime = Math.floor(s / 3600) + "h " + Math.floor((s % 3600) / 60) + "m"
        }
    }
    FileView {
        path: "/proc/cpuinfo"
        onLoaded: {
            const m = text().match(/^model name\s*:\s*(.+)/m)
            root.sysCPU = (m ? m[1] : "").replace(/\(R\)/g,"").replace(/\(TM\)/g,"").replace(/\s+/g," ").trim()
        }
    }
    Process {
        running: true
        command: ["uname", "-m"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root.sysArch = data.trim() }
    }

    // ── PCI: ls /sys/bus/pci/devices → sequential uevent reads ───────────
    Process {
        running: true
        command: ["ls", "/sys/bus/pci/devices"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const slot = data.trim()
                if (slot) root._pciQ.push(slot)
            }
        }
        onExited: {
            root._pciQi = 0
            root._pciAcc = []
            if (root._pciQ.length > 0)
                pciReader.path = "/sys/bus/pci/devices/" + root._pciQ[0] + "/uevent"
            else { root._pciScanDone = true; root._buildPci() }
        }
    }

    FileView {
        id: pciReader
        onLoaded: {
            const txt  = text()
            const slot = (txt.match(/^PCI_SLOT_NAME=(.+)/m) ?? [])[1]?.trim() ?? root._pciQ[root._pciQi]
            const idm  = txt.match(/^PCI_ID=([0-9a-fA-F]{4}):([0-9a-fA-F]{4})/m)
            const drv  = (txt.match(/^DRIVER=(.+)/m) ?? [])[1]?.trim() ?? ""
            if (idm) {
                root._pciAcc.push({
                    slot, drv,
                    vid: idm[1].toLowerCase(),
                    did: idm[2].toLowerCase()
                })
            }
            root._pciQi++
            if (root._pciQi < root._pciQ.length)
                pciReader.path = "/sys/bus/pci/devices/" + root._pciQ[root._pciQi] + "/uevent"
            else { root._pciScanDone = true; root._buildPci() }
        }
    }

    // ── pci.ids loader — optional, enriches names after scan completes ─────
    FileView {
        id: pciIdsView
        Component.onCompleted: path = "/etc/quickshell/pci.ids"
        onLoaded: { root._parsePciIds(text()); root._buildPci() }
    }

    // ── usb.ids loader — optional, enriches names after scan completes ─────
    FileView {
        id: usbIdsView
        Component.onCompleted: path = "/etc/quickshell/usb.ids"
        onLoaded: { root._parseUsbIds(text()); root._buildUsb() }
    }

    // ── USB uevent reader — phase 1 ────────────────────────────────────────
    FileView {
        id: usbEvetReader
        onLoaded: {
            const txt     = text()
            const devtype = (txt.match(/^DEVTYPE=(.+)/m)  ?? [])[1]?.trim()
            const driver  = (txt.match(/^DRIVER=(.+)/m)   ?? [])[1]?.trim()
            const pm      = txt.match(/^PRODUCT=([0-9a-fA-F]+)\/([0-9a-fA-F]+)/m)
            if (devtype === "usb_device" && driver !== "hub" && pm)
                root._usbValidDevs.push({
                    dir: root._usbEvetQ[root._usbEvetQi].dir,
                    vid: pm[1].toLowerCase().padStart(4, '0'),
                    pid: pm[2].toLowerCase().padStart(4, '0')
                })
            root._usbEvetQi++
            if (root._usbEvetQi < root._usbEvetQ.length) {
                usbEvetReader.path = root._usbEvetQ[root._usbEvetQi].path
            } else {
                root._usbSpdQ = root._usbValidDevs.slice()
                root._usbSpdQi = 0
                root._usbAcc = []
                if (root._usbSpdQ.length > 0) usbSpdReader.path = root._usbSpdQ[0].dir + "/speed"
                else { root._usbScanDone = true; root._buildUsb() }
            }
        }
    }

    // ── USB speed reader — phase 2 ─────────────────────────────────────────
    FileView {
        id: usbSpdReader
        onLoaded: {
            const item = root._usbSpdQ[root._usbSpdQi]
            root._usbAcc.push({ vid: item.vid, pid: item.pid, spd: text().trim() })
            root._usbSpdQi++
            if (root._usbSpdQi < root._usbSpdQ.length) usbSpdReader.path = root._usbSpdQ[root._usbSpdQi].dir + "/speed"
            else { root._usbScanDone = true; root._buildUsb() }
        }
    }

    // ── USB: ls /sys/bus/usb/devices → sequential uevent reads ───────────
    Process {
        running: true
        command: ["ls", "/sys/bus/usb/devices"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const name = data.trim()
                // skip interface nodes (contain ":") — keep only device nodes
                if (name && !name.includes(":")) {
                    const dir = "/sys/bus/usb/devices/" + name
                    root._usbEvetQ.push({ dir, path: dir + "/uevent" })
                }
            }
        }
        onExited: {
            root._usbEvetQi = 0
            root._usbValidDevs = []
            if (root._usbEvetQ.length > 0)
                usbEvetReader.path = root._usbEvetQ[0].path
            else { root._usbScanDone = true; root._buildUsb() }
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: Constants.innerPadding * 2 }
        spacing: Constants.innerPadding * 2

        // System info header card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + Constants.innerPadding * 2
            radius: Constants.radius
            color: Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.5)

            RowLayout {
                id: headerRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Constants.innerPadding * 2 }
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
                        text: root.sysHostname
                        color: Constants.nord6; font.family: Constants.font.family
                        font.pointSize: Constants.font.normalSize; font.bold: true
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: root.sysOS
                        color: Constants.nord9; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                    }
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: Constants.nord3; opacity: 0.5 }

                GridLayout {
                    columns: 4
                    columnSpacing: Constants.innerPadding
                    rowSpacing: 6

                    Repeater {
                        model: [
                            { label: "Kernel", value: root.sysKernel },
                            { label: "Arch",   value: root.sysArch   },
                            { label: "CPU",    value: root.sysCPU    },
                            { label: "Uptime", value: root.sysUptime },
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
                                font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                                Layout.minimumWidth: 55
                            }
                            Text {
                                text: infoRow.modelData.value
                                color: Constants.nord6; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
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
                delegate: Rectangle {
                    id: tabBtn
                    required property string modelData
                    required property int index
                    Layout.preferredWidth: 120; height: 28; radius: Constants.radius
                    color: root._devTab === tabBtn.index ? Constants.nord8 : Constants.nord2
                    Behavior on color { CAnim {} }
                    Text {
                        anchors.centerIn: parent
                        text: tabBtn.modelData
                        color: root._devTab === tabBtn.index ? Constants.nord0 : Constants.nord4
                        font.family: Constants.font.family; font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        Behavior on color { CAnim {} }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root._devTab = tabBtn.index }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (root._devTab === 0 ? root.pciDevices.length : root.usbDevices.length) + " devices"
                color: Constants.nord3; font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
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
            model: root._devTab === 0 ? root.pciDevices : root.usbDevices

            delegate: Rectangle {
                id: devDelegate
                required property var modelData
                required property int index
                width: deviceList.width
                height: 28
                radius: 4
                color: devDelegate.index % 2 === 0 ? "transparent" : Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.3)

                // PCI row
                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                    spacing: Constants.innerPadding
                    visible: root._devTab === 0

                    Text {
                        text: devDelegate.modelData.slot ?? ""
                        color: Constants.nord3; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                        Layout.minimumWidth: 80
                    }
                    Text {
                        Layout.fillWidth: true
                        text: devDelegate.modelData.name ?? ""
                        color: Constants.nord6; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                    Text {
                        text: devDelegate.modelData.drv ?? ""
                        color: Constants.nord3; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                        Layout.minimumWidth: 80; horizontalAlignment: Text.AlignRight
                    }
                }

                // USB row
                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                    spacing: Constants.innerPadding
                    visible: root._devTab === 1

                    Text {
                        text: devDelegate.modelData.id ?? ""
                        color: Constants.nord3; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                        Layout.minimumWidth: 90
                    }
                    Text {
                        Layout.fillWidth: true
                        text: devDelegate.modelData.name ?? ""
                        color: Constants.nord6; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                    Text {
                        text: (devDelegate.modelData.spd ?? "") + (devDelegate.modelData.spd ? " Mb/s" : "")
                        color: Constants.nord3; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                        Layout.minimumWidth: 70
                        horizontalAlignment: Text.AlignRight
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
