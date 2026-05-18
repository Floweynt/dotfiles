pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components
import qs.sysmon 1.0

Item {
    id: root

    readonly property var sysmon: SysmonProvider

    // ── Sort / filter / pin state ───────────────────────────────────────────
    property string filterText: ""
    property string sortCol: "cpu"   // pid | name | cpu | mem | res | thr | state
    property bool   sortAsc: false
    property var    pinnedPids: []  // pinned by PID

    function togglePin(pid) {
        const idx = pinnedPids.indexOf(pid)
        if (idx >= 0) {
            const arr = pinnedPids.slice(); arr.splice(idx, 1); pinnedPids = arr
        } else {
            pinnedPids = [...pinnedPids, pid]
        }
        rebuildList()
    }

    // Formatted KiB → human-readable
    function fmtKib(kib) {
        if (kib >= 1024 * 1024) return (kib / (1024 * 1024)).toFixed(1) + "G"
        if (kib >= 1024)        return (kib / 1024).toFixed(0) + "M"
        return kib + "K"
    }

    // Re-sort + filter whenever data or sort params change
    ListModel { id: displayModel }

    function rebuildList() {
        const raw = sysmon.processes
        const ft  = root.filterText.toLowerCase()
        let arr = ft ? raw.filter(p => p.name.toLowerCase().includes(ft) || String(p.pid).includes(ft)) : raw.slice()

        const col = root.sortCol
        const asc = root.sortAsc
        arr.sort((a, b) => {
            let va, vb
            if      (col === "pid")   { va = a.pid;     vb = b.pid }
            else if (col === "name")  { va = a.name;    vb = b.name }
            else if (col === "cpu")   { va = a.cpu;     vb = b.cpu }
            else if (col === "mem")   { va = a.mem;     vb = b.mem }
            else if (col === "res")   { va = a.memKib;  vb = b.memKib }
            else if (col === "thr")   { va = a.threads; vb = b.threads }
            else if (col === "state") { va = a.state;   vb = b.state }
            else                      { va = a.cpu;     vb = b.cpu }
            if (va < vb) return asc ? -1 : 1
            if (va > vb) return asc ? 1 : -1
            return 0
        })

        // Float pinned PIDs to top (preserving sort within each group)
        const pinSet = new Set(root.pinnedPids)
        const pinned   = arr.filter(p => pinSet.has(p.pid))
        const unpinned = arr.filter(p => !pinSet.has(p.pid))
        arr = [...pinned, ...unpinned]

        displayModel.clear()
        for (const p of arr) {
            displayModel.append({
                pid:     p.pid,
                name:    p.name,
                cpu:     p.cpu,
                mem:     p.mem,
                memKib:  p.memKib,
                threads: p.threads,
                state:   p.state
            })
        }
    }

    Connections {
        target: sysmon
        function onProcsUpdated() { if (root.visible) root.rebuildList() }
    }
    onVisibleChanged:    if (visible) rebuildList()
    onFilterTextChanged: rebuildList()
    onSortColChanged:    rebuildList()
    onSortAscChanged:    rebuildList()

    // ── Column definitions ──────────────────────────────────────────────────
    readonly property var cols: [
        { id: "pid",   label: "PID",   width: 52,  align: Text.AlignRight  },
        { id: "name",  label: "Name",  width: -1,  align: Text.AlignLeft   },
        { id: "cpu",   label: "CPU%",  width: 58,  align: Text.AlignRight  },
        { id: "mem",   label: "MEM%",  width: 58,  align: Text.AlignRight  },
        { id: "res",   label: "RES",   width: 64,  align: Text.AlignRight  },
        { id: "thr",   label: "THR",   width: 40,  align: Text.AlignRight  },
        { id: "state", label: "S",     width: 20,  align: Text.AlignHCenter },
    ]

    function sortBy(col) {
        if (root.sortCol === col) root.sortAsc = !root.sortAsc
        else { root.sortCol = col; root.sortAsc = false }
    }

    ColumnLayout {
        anchors { fill: parent; margins: Constants.innerPadding * 2 }
        spacing: Constants.innerPadding

        // ── Top bar: filter + count ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            Rectangle {
                Layout.fillWidth: true; height: 28
                color: Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.5)
                radius: 4
                border.color: filterField.activeFocus ? Constants.nord8 : Constants.nord3
                border.width: 1

                Text {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                    text: "Filter by name or PID…"
                    color: Constants.nord3
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize
                    renderType: Text.NativeRendering
                    visible: filterField.text.length === 0
                }
                TextInput {
                    id: filterField
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                    color: Constants.nord6
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize
                    selectionColor: Qt.rgba(Constants.nord8.r, Constants.nord8.g, Constants.nord8.b, 0.4)
                    onTextChanged: root.filterText = text
                    Keys.onEscapePressed: { clear(); root.filterText = "" }
                }
            }

            Text {
                text: displayModel.count + " / " + sysmon.processes.length + " proc"
                color: Constants.nord3
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize - 1
                renderType: Text.NativeRendering
            }
        }

        // ── Header row ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 26
            color: Qt.rgba(Constants.nord0.r, Constants.nord0.g, Constants.nord0.b, 0.7)
            radius: 4

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 + 6 }
                spacing: 4

                Repeater {
                    model: root.cols
                    delegate: Item {
                        id: hdrItem
                        required property var modelData

                        Layout.preferredWidth: hdrItem.modelData.width > 0 ? hdrItem.modelData.width : -1
                        Layout.fillWidth: hdrItem.modelData.width < 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sortBy(hdrItem.modelData.id)
                        }

                        Text {
                            anchors.fill: parent
                            text: {
                                const label = hdrItem.modelData.label
                                if (root.sortCol !== hdrItem.modelData.id) return label
                                return label + (root.sortAsc ? " ▲" : " ▼")
                            }
                            color: root.sortCol === hdrItem.modelData.id ? Constants.nord8 : Constants.nord4
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 1
                            renderType: Text.NativeRendering
                            horizontalAlignment: hdrItem.modelData.align
                            verticalAlignment: Text.AlignVCenter
                            Behavior on color { CAnim {} }
                        }
                    }
                }

                // Spacers for pin + kill button columns
                Item { Layout.preferredWidth: 20 }
                Item { Layout.preferredWidth: 52 }
            }
        }

        // ── Process list ────────────────────────────────────────────────────
        ListView {
            id: procList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            model: displayModel

            // Confirmation state for kill dialog
            property int pendingKillPid: -1
            property int pendingKillSig: 15
            property string pendingKillName: ""

            delegate: Rectangle {
                id: procRow
                required property int   index
                required property int    pid
                required property string name
                required property real   cpu
                required property real   mem
                required property real   memKib
                required property int    threads
                required property string state

                width: procList.width
                height: 26
                radius: 3
                readonly property bool isPinned: root.pinnedPids.indexOf(procRow.pid) >= 0

                color: procRow.isPinned
                    ? Qt.rgba(Constants.nord8.r, Constants.nord8.g, Constants.nord8.b, 0.08)
                    : procRow.index % 2 === 0
                        ? "transparent"
                        : Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.18)

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 4

                    // PID
                    Text {
                        Layout.preferredWidth: 52
                        text: procRow.pid
                        color: Constants.nord3
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize - 1
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignRight
                    }

                    // Name
                    Text {
                        Layout.fillWidth: true
                        text: procRow.name
                        color: Constants.nord6
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                    }

                    // CPU%
                    Text {
                        Layout.preferredWidth: 58
                        text: procRow.cpu.toFixed(1)
                        color: procRow.cpu > 80 ? Constants.nord11
                             : procRow.cpu > 40 ? Constants.nord13
                             : procRow.cpu > 5  ? Constants.nord9
                             : Constants.nord4
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignRight
                    }

                    // MEM%
                    Text {
                        Layout.preferredWidth: 58
                        text: procRow.mem.toFixed(1)
                        color: procRow.mem > 20 ? Constants.nord11
                             : procRow.mem > 8  ? Constants.nord13
                             : Constants.nord4
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignRight
                    }

                    // RES
                    Text {
                        Layout.preferredWidth: 64
                        text: root.fmtKib(procRow.memKib)
                        color: Constants.nord4
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignRight
                    }

                    // THR
                    Text {
                        Layout.preferredWidth: 40
                        text: procRow.threads
                        color: Constants.nord3
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignRight
                    }

                    // State
                    Text {
                        Layout.preferredWidth: 20
                        text: procRow.state
                        color: procRow.state === "R" ? Constants.nord14
                             : procRow.state === "D" ? Constants.nord13
                             : procRow.state === "Z" ? Constants.nord11
                             : Constants.nord3
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Pin button
                    Text {
                        width: 20
                        text: procRow.isPinned ? "󰐃" : "󰐴"
                        color: procRow.isPinned ? Constants.nord8 : Constants.nord3
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        horizontalAlignment: Text.AlignHCenter
                        Behavior on color { CAnim {} }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePin(procRow.pid)
                        }
                    }

                    // Kill button
                    Rectangle {
                        width: 52; height: 18
                        radius: 3
                        color: killArea.pressed ? Qt.rgba(Constants.nord11.r, Constants.nord11.g, Constants.nord11.b, 0.6)
                             : killArea.containsMouse ? Qt.rgba(Constants.nord11.r, Constants.nord11.g, Constants.nord11.b, 0.35)
                             : Qt.rgba(Constants.nord11.r, Constants.nord11.g, Constants.nord11.b, 0.15)
                        Behavior on color { CAnim {} }

                        Text {
                            anchors.centerIn: parent
                            text: killArea.containsPress && (killArea.pressedButtons & Qt.RightButton) ? "KILL" : "TERM"
                            color: Constants.nord11
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: killArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: (mouse) => {
                                const sig = (mouse.button === Qt.RightButton) ? 9 : 15
                                procList.pendingKillPid  = procRow.pid
                                procList.pendingKillSig  = sig
                                procList.pendingKillName = procRow.name
                                killConfirm.open()
                            }
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 4; radius: 2
                    color: Constants.nord3; opacity: 0.6
                }
            }

            // ── Kill confirmation popup ──────────────────────────────────────
            Popup {
                id: killConfirm
                anchors.centerIn: parent
                width: 300; height: confirmCol.implicitHeight + Constants.innerPadding * 4
                modal: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                padding: Constants.innerPadding * 2

                background: Rectangle {
                    color: Constants.nord1; radius: Constants.radius
                    border.color: Constants.nord3; border.width: 1
                }

                ColumnLayout {
                    id: confirmCol
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    spacing: Constants.innerPadding

                    Text {
                        Layout.fillWidth: true
                        text: procList.pendingKillSig === 9 ? "Force-kill process?" : "Terminate process?"
                        color: Constants.nord11
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize + 1
                        renderType: Text.NativeRendering
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: procList.pendingKillName + "  (PID " + procList.pendingKillPid + ")"
                              + "\nSIG" + (procList.pendingKillSig === 9 ? "KILL" : "TERM")
                        color: Constants.nord6
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.innerPadding

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 70; height: 28; radius: 4
                            color: cancelArea.containsMouse
                                ? Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.8)
                                : Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.4)
                            Behavior on color { CAnim {} }
                            Text {
                                anchors.centerIn: parent; text: "Cancel"
                                color: Constants.nord4
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                id: cancelArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: killConfirm.close()
                            }
                        }

                        Rectangle {
                            width: 70; height: 28; radius: 4
                            color: confirmArea.containsMouse
                                ? Qt.rgba(Constants.nord11.r, Constants.nord11.g, Constants.nord11.b, 0.7)
                                : Qt.rgba(Constants.nord11.r, Constants.nord11.g, Constants.nord11.b, 0.45)
                            Behavior on color { CAnim {} }
                            Text {
                                anchors.centerIn: parent
                                text: procList.pendingKillSig === 9 ? "Kill" : "Terminate"
                                color: Constants.nord6
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                id: confirmArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sysmon.killProcess(procList.pendingKillPid, procList.pendingKillSig)
                                    killConfirm.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
