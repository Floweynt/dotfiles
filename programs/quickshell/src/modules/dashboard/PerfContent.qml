pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components
import qs.floweyshell 1.0
import "GraphHelpers.js" as G

Item {
    id: root

    // History arrays; maintained here so sparkline canvases can read them without C++ round-trips
    property var cpuHistory: []
    property var cpuCoreHistory: []
    property var memHistory: []
    property var memCachedHistory: []
    property var cpuTempHistory: []
    property var gpuTempHistories: [[], []]
    property var gpuBusyHistories: [[], []]
    property var gpuVramHistories: [[], []]

    // 8 accent colors, cycled for 16 cores
    readonly property var _coreColors: [
        Constants.nord8,  Constants.nord11, Constants.nord14, Constants.nord13,
        Constants.nord9,  Constants.nord12, Constants.nord7,  Constants.nord10,
    ]

    readonly property var sysmon: SysmonProvider

    Connections {
        target: sysmon

        function onCpuUpdated() {
            const hist = root.cpuHistory.slice(-59)
            hist.push(sysmon.cpuTotal)
            root.cpuHistory = hist

            const cores = sysmon.cpuCores
            const histories = root.cpuCoreHistory.slice()
            for (let i = 0; i < cores.length; i++) {
                const h = (histories[i] ?? []).slice(-59)
                h.push(cores[i])
                histories[i] = h
            }
            root.cpuCoreHistory = histories

            const th = root.cpuTempHistory.slice(-59)
            th.push(sysmon.cpuTemp)
            root.cpuTempHistory = th

            if (!root.visible) return
            if (cpuCard.cpuTab === 0) cpuGraph.requestPaint()
            else coreCanvas.requestPaint()
        }

        function onGpusUpdated() {
            const gpus = sysmon.gpus
            const tempH = root.gpuTempHistories.slice()
            const busyH = root.gpuBusyHistories.slice()
            const vramH = root.gpuVramHistories.slice()
            for (let i = 0; i < Math.min(gpus.length, 2); i++) {
                const g = gpus[i] ?? {}

                const th = (tempH[i] ?? []).slice(-59); th.push(g.temp ?? 0); tempH[i] = th
                const bh = (busyH[i] ?? []).slice(-59); bh.push(g.busy ?? 0); busyH[i] = bh
                const vt = g.vramTotal ?? 1
                const vh = (vramH[i] ?? []).slice(-59); vh.push(vt > 0 ? (g.vramUsed ?? 0) / vt * 100 : 0); vramH[i] = vh
            }
            root.gpuTempHistories = tempH
            root.gpuBusyHistories = busyH
            root.gpuVramHistories = vramH

            if (!root.visible) return
            tempGraph.requestPaint()
        }

        function onMemUpdated() {
            const total = sysmon.memTotal
            const uh = root.memHistory.slice(-59)
            uh.push(total > 0 ? (sysmon.memUsed / total) * 100 : 0)
            root.memHistory = uh
            const ch = root.memCachedHistory.slice(-59)
            ch.push(total > 0 ? (sysmon.memCached / total) * 100 : 0)
            root.memCachedHistory = ch

            if (!root.visible) return
            memGraph.requestPaint()
            memBar.requestPaint()
        }
    }

    RowLayout {
        anchors { fill: parent; margins: Constants.innerPadding * 2 }
        spacing: Constants.innerPadding * 2

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Constants.innerPadding * 2

            // CPU card
            CardBox {
                id: cpuCard
                property int cpuTab: 0
                onCpuTabChanged: cpuTab === 0 ? cpuGraph.requestPaint() : coreCanvas.requestPaint()

                Layout.fillWidth: true

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "CPU"
                            color: Constants.nord4; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: sysmon.cpuTemp > 0
                            text: sysmon.cpuTemp.toFixed(1) + "°C"
                            color: sysmon.cpuTemp > 90 ? Constants.nord11
                                 : sysmon.cpuTemp > 70 ? Constants.nord13
                                 : Constants.nord8
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2
                            renderType: Text.NativeRendering
                            Behavior on color { CAnim {} }
                        }
                        Text {
                            visible: sysmon.cpuFreq > 0
                            text: sysmon.cpuFreq + " MHz"
                            color: Constants.nord7
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2
                            renderType: Text.NativeRendering
                        }
                    }

                    // Tab buttons
                    RowLayout {
                        Layout.fillWidth: true; spacing: 4

                        ChipButton {
                            Layout.fillWidth: true
                            label: "Overall"
                            active: cpuCard.cpuTab === 0
                            onClicked: cpuCard.cpuTab = 0
                        }
                        ChipButton {
                            Layout.fillWidth: true
                            label: "Per Core"
                            active: cpuCard.cpuTab === 1
                            onClicked: cpuCard.cpuTab = 1
                        }
                    }

                    // Tab content
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: cpuCard.cpuTab

                        // Overall tab
                        ColumnLayout {
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                StatBar {
                                    Layout.fillWidth: true
                                    value: sysmon.cpuTotal / 100
                                    fillColor: sysmon.cpuTotal > 80 ? Constants.nord11
                                             : sysmon.cpuTotal > 50 ? Constants.nord13
                                             : Constants.nord14
                                }
                                Text {
                                    text: sysmon.cpuTotal.toFixed(1) + "%"
                                    color: sysmon.cpuTotal > 80 ? Constants.nord11
                                         : sysmon.cpuTotal > 50 ? Constants.nord13
                                         : Constants.nord14
                                    font.family: Constants.font.family
                                    font.pointSize: Constants.font.smallSize - 2
                                    renderType: Text.NativeRendering
                                    Layout.minimumWidth: 36; horizontalAlignment: Text.AlignRight
                                    Behavior on color { CAnim {} }
                                }
                            }

                            Canvas {
                                id: cpuGraph
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    const c = Constants.nord8.toString().slice(1)
                                    G.drawSparkline(ctx, root.cpuHistory, width, height, 100,
                                        "#AA" + c, "#22" + c)
                                    G.drawBorder(ctx, width, height, Constants.nord3.toString())
                                }
                            }
                        }

                        // Per Core tab
                        Canvas {
                            id: coreCanvas
                            Layout.fillWidth: true
                            readonly property int cellRows: root.cpuCoreHistory.length > 0 ? Math.ceil(root.cpuCoreHistory.length / 4) : 4
                            implicitHeight: cellRows * 54
                            height: implicitHeight
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                const histories = root.cpuCoreHistory
                                if (histories.length === 0) return

                                const cols  = 4
                                const cellW = width / cols
                                const cellH = 54
                                const pad   = 4
                                const lblH  = 14

                                for (let i = 0; i < histories.length; i++) {
                                    const col = i % cols
                                    const row = Math.floor(i / cols)
                                    const x0  = col * cellW + pad
                                    const y0  = row * cellH + pad
                                    const w   = cellW - pad * 2
                                    const h   = cellH - lblH - pad * 2

                                    const color    = root._coreColors[i % 8]
                                    const colorStr = color.toString()
                                    const hist     = histories[i] ?? []

                                    ctx.fillStyle = Constants.nord1.toString()
                                    ctx.fillRect(x0, y0 + lblH, w, h)

                                    if (hist.length >= 2) {
                                        ctx.beginPath()
                                        for (let j = 0; j < hist.length; j++) {
                                            const px = x0 + (j / 59) * w
                                            const py = y0 + lblH + h - (hist[j] / 100) * h
                                            j === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py)
                                        }
                                        ctx.lineTo(x0 + ((hist.length - 1) / 59) * w, y0 + lblH + h)
                                        ctx.lineTo(x0, y0 + lblH + h)
                                        ctx.closePath()
                                        ctx.fillStyle = "#33" + colorStr.slice(1)
                                        ctx.fill()

                                        ctx.beginPath()
                                        for (let j = 0; j < hist.length; j++) {
                                            const px = x0 + (j / 59) * w
                                            const py = y0 + lblH + h - (hist[j] / 100) * h
                                            j === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py)
                                        }
                                        ctx.strokeStyle = "#CC" + colorStr.slice(1)
                                        ctx.lineWidth = 1
                                        ctx.stroke()
                                    }

                                    ctx.fillStyle = colorStr
                                    ctx.font = "bold 9px " + Constants.font.family
                                    ctx.textAlign = "left"
                                    ctx.textBaseline = "top"
                                    ctx.fillText("C" + i, x0 + 2, y0 + 1)

                                    const cur = hist.length > 0 ? hist[hist.length - 1] : 0
                                    ctx.textAlign = "right"
                                    ctx.fillText(Math.round(cur) + "%", x0 + w - 1, y0 + 1)
                                    ctx.strokeStyle = Constants.nord3.toString()
                                    ctx.lineWidth = 0.5
                                    ctx.strokeRect(x0 + 0.5, y0 + lblH + 0.5, w - 1, h - 1)
                                }
                            }
                        }
                    }
            }

            // Memory card
            CardBox {
                Layout.fillWidth: true

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Memory"
                            color: Constants.nord4; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: sysmon.memUsed.toFixed(1) + " / " + sysmon.memTotal.toFixed(1) + "G"
                            color: Constants.nord4; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Canvas {
                            id: memBar
                            Layout.fillWidth: true; height: 10
                            onWidthChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                const total = sysmon.memTotal
                                const fAll  = total > 0 ? (sysmon.memUsed + sysmon.memCached) / total : 0
                                const fUsed = total > 0 ? sysmon.memUsed / total : 0
                                const r = 3

                                // Left-rounded rectangle: rounds only the left two corners.
                                const lr = fw => {
                                    ctx.beginPath()
                                    ctx.moveTo(r, 0)
                                    ctx.lineTo(fw, 0)
                                    ctx.lineTo(fw, height)
                                    ctx.lineTo(r, height)
                                    ctx.arc(r, height - r, r, Math.PI / 2, Math.PI)
                                    ctx.lineTo(0, r)
                                    ctx.arc(r, r, r, Math.PI, Math.PI * 1.5)
                                    ctx.closePath()
                                }

                                ctx.fillStyle = Constants.nord1.toString()
                                ctx.fillRect(0, 0, width, height)

                                if (fAll > 0) { lr(fAll * width); ctx.fillStyle = Constants.nord9.toString(); ctx.fill() }
                                if (fUsed > 0) { lr(fUsed * width); ctx.fillStyle = Constants.nord10.toString(); ctx.fill() }

                                ctx.strokeStyle = Constants.nord3.toString()
                                ctx.lineWidth = 1
                                ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
                            }
                        }
                        Text {
                            text: sysmon.memUsed.toFixed(1) + "G used"
                            color: Constants.nord10; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: sysmon.memCached.toFixed(1) + "G cached"
                            color: Constants.nord9; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: sysmon.memFree.toFixed(1) + "G free"
                            color: Constants.nord3; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Canvas {
                        id: memGraph
                        Layout.fillWidth: true
                        height: 56
                        onWidthChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const uh = root.memHistory
                            const ch = root.memCachedHistory
                            const combined = uh.map((v, i) => v + (ch[i] ?? 0))
                            const nord9  = Constants.nord9.toString().slice(1)
                            const nord10 = Constants.nord10.toString().slice(1)
                            G.drawSparkline(ctx, combined, width, height, 100, null, "#44" + nord9)
                            G.drawSparkline(ctx, uh, width, height, 100, "#CC" + nord10, "#88" + nord10)
                            G.drawBorder(ctx, width, height, Constants.nord3.toString())
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        visible: sysmon.swapTotal > 0
                        Text {
                            text: "Swap"; color: Constants.nord3; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            Layout.minimumWidth: 32
                        }
                        StatBar {
                            Layout.fillWidth: true
                            trackHeight: 4
                            value: sysmon.swapTotal > 0 ? sysmon.swapUsed / sysmon.swapTotal : 0
                            fillColor: Constants.nord9
                        }
                        Text {
                            text: sysmon.swapUsed.toFixed(1) + " / " + sysmon.swapTotal.toFixed(1) + "G"
                            color: Constants.nord3; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            horizontalAlignment: Text.AlignRight
                        }
                    }
            }

            // Battery card
            CardBox {
                Layout.fillWidth: true
                visible: sysmon.battPct >= 0

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: sysmon.battCharging ? "󰂄"
                                : sysmon.battPct > 75 ? "󰁹"
                                : sysmon.battPct > 50 ? "󰂀"
                                : sysmon.battPct > 25 ? "󰁾" : "󰁺"
                            color: sysmon.battCharging ? Constants.nord14
                                 : sysmon.battPct < 20  ? Constants.nord11
                                 : Constants.nord4
                            font.family: Constants.font.family; font.pointSize: Constants.font.iconSize
                            renderType: Text.NativeRendering
                            Behavior on color { CAnim {} }
                        }
                        Text {
                            text: "Battery"
                            color: Constants.nord4; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: sysmon.battStatus
                            color: sysmon.battCharging ? Constants.nord14 : Constants.nord3
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            Behavior on color { CAnim {} }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        StatBar {
                            Layout.fillWidth: true
                            trackHeight: 5
                            value: sysmon.battPct / 100
                            fillColor: sysmon.battCharging ? Constants.nord14
                                     : sysmon.battPct < 20 ? Constants.nord11
                                     : Constants.nord8
                        }
                        Text {
                            text: sysmon.battPct + "%"
                            color: sysmon.battPct < 20 ? Constants.nord11 : Constants.nord6
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            Layout.minimumWidth: 30; horizontalAlignment: Text.AlignRight
                            Behavior on color { CAnim {} }
                        }
                    }
            }

            // GPU cards
            // model: 2 keeps delegates alive across polls; reading sysmon.gpus[index]
            // directly as a binding avoids the destroy/recreate cycle that resets animations.
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Constants.innerPadding
                rowSpacing: Constants.innerPadding

            Repeater {
                model: 2
                delegate: CardBox {
                    id: gpuCard
                    required property int index
                    required property int modelData
                    readonly property var gpu: sysmon.gpus.length > index ? sysmon.gpus[index] : ({})

                    Layout.fillWidth: true
                    visible: sysmon.gpus.length > index
                    spacing: 5
                    opacity: gpuCard.gpu.active ? 1 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 400 } }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: gpuCard.gpu.name ?? ""
                                color: Constants.nord4; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (gpuCard.gpu.temp ?? 0) + "°C"
                                color: (gpuCard.gpu.temp ?? 0) > 80 ? Constants.nord11
                                     : (gpuCard.gpu.temp ?? 0) > 60 ? Constants.nord13
                                     : Constants.nord8
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                                Behavior on color { CAnim {} }
                            }
                            Text {
                                text: ((gpuCard.gpu.power ?? 0) / 1000).toFixed(1) + "W"
                                color: Constants.nord13
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            }
                            Text {
                                text: (gpuCard.gpu.freq ?? 0) + " MHz"
                                color: Constants.nord7
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text {
                                text: "GPU"; color: Constants.nord3; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                                Layout.minimumWidth: 32
                            }
                            StatBar {
                                Layout.fillWidth: true
                                readonly property int _busy: gpuCard.gpu.busy ?? 0
                                value: _busy / 100
                                fillColor: _busy > 80 ? Constants.nord11
                                         : _busy > 50 ? Constants.nord13
                                         : Constants.nord7
                            }
                            Text {
                                text: (gpuCard.gpu.busy ?? 0) + "%"
                                color: Constants.nord4; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                                Layout.minimumWidth: 30; horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text {
                                text: "VRAM"; color: Constants.nord3; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                                Layout.minimumWidth: 32
                            }
                            StatBar {
                                Layout.fillWidth: true
                                readonly property real _frac: (gpuCard.gpu.vramTotal ?? 0) > 0
                                    ? (gpuCard.gpu.vramUsed ?? 0) / gpuCard.gpu.vramTotal : 0
                                value: _frac
                                fillColor: _frac > 0.8 ? Constants.nord11
                                         : _frac > 0.5 ? Constants.nord13
                                         : Constants.nord9
                            }
                            Text {
                                text: ((gpuCard.gpu.vramUsed ?? 0) / 1073741824).toFixed(1) + " / " +
                                      ((gpuCard.gpu.vramTotal ?? 0) / 1073741824).toFixed(1) + "G"
                                color: Constants.nord4; font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2; renderType: Text.NativeRendering
                                Layout.minimumWidth: 60; horizontalAlignment: Text.AlignRight
                            }
                        }

                        Canvas {
                            id: gpuHistCanvas
                            Layout.fillWidth: true
                            height: 56

                            Connections {
                                target: sysmon
                                function onGpusUpdated() { if (root.visible) gpuHistCanvas.requestPaint() }
                            }

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                const nord9 = Constants.nord9.toString().slice(1)
                                const nord7 = Constants.nord7.toString().slice(1)
                                G.drawSparkline(ctx, root.gpuVramHistories[gpuCard.index] ?? [],
                                    width, height, 100, "#AA" + nord9, "#22" + nord9)
                                G.drawSparkline(ctx, root.gpuBusyHistories[gpuCard.index] ?? [],
                                    width, height, 100, "#CC" + nord7, "#33" + nord7)
                                G.drawBorder(ctx, width, height, Constants.nord3.toString())
                            }
                        }
                    }
            }
            } // GridLayout

            // Temperature card
            CardBox {
                Layout.fillWidth: true

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Temperatures"
                            color: Constants.nord4; font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [
                                { label: "CPU",  color: Constants.nord8,  temp: sysmon.cpuTemp },
                                { label: "dGPU", color: Constants.nord11, temp: (sysmon.gpus[0] ?? {}).temp ?? 0 },
                                { label: "iGPU", color: Constants.nord13, temp: (sysmon.gpus[1] ?? {}).temp ?? 0 },
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 3
                                Rectangle { width: 8; height: 8; radius: 2; color: parent.modelData.color }
                                Text {
                                    text: parent.modelData.label + " " + parent.modelData.temp.toFixed(0) + "°"
                                    color: parent.modelData.temp > 80 ? Constants.nord11
                                         : parent.modelData.temp > 60 ? Constants.nord13
                                         : Constants.nord4
                                    font.family: Constants.font.family
                                    font.pointSize: Constants.font.smallSize - 2
                                    renderType: Text.NativeRendering
                                    Behavior on color { CAnim {} }
                                }
                            }
                        }
                    }

                    Canvas {
                        id: tempGraph
                        Layout.fillWidth: true
                        height: 120

                        readonly property var _series: [
                            { history: root.cpuTempHistory,        color: Constants.nord8  },
                            { history: root.gpuTempHistories[0],   color: Constants.nord11 },
                            { history: root.gpuTempHistories[1],   color: Constants.nord13 },
                        ]

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const maxTemp = 110
                            const warnY = height - (80 / maxTemp) * height
                            const critY = height - (90 / maxTemp) * height
                            ctx.setLineDash([3, 3])
                            ctx.lineWidth = 0.5
                            ctx.strokeStyle = Constants.nord13.toString()
                            ctx.beginPath(); ctx.moveTo(0, warnY); ctx.lineTo(width, warnY); ctx.stroke()
                            ctx.strokeStyle = Constants.nord11.toString()
                            ctx.beginPath(); ctx.moveTo(0, critY); ctx.lineTo(width, critY); ctx.stroke()
                            ctx.setLineDash([])
                            for (const s of tempGraph._series)
                                G.drawSparkline(ctx, s.history ?? [], width, height, maxTemp,
                                    "#CC" + s.color.toString().slice(1), null)
                            G.drawBorder(ctx, width, height, Constants.nord3.toString())
                        }
                    }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
