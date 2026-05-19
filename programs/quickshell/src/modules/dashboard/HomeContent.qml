pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
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
                    root._backlightDev = parts[0]
                    root.brightness    = parseInt(parts[1]) || 50
                    root.maxBrightness = parseInt(parts[2]) || 100
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

    // -------------------------------------------------------------------------
    // Weather via wttr.in
    // -------------------------------------------------------------------------
    property string weatherTemp: "-"
    property string weatherDesc: "Loading..."
    property string weatherIcon: "󰖐"
    property string weatherCity: ""

    Component.onCompleted: fetchWeather()

    function fetchWeather() {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== 4) return
            if (xhr.status === 200) {
                try {
                    const d = JSON.parse(xhr.responseText)
                    const c = d.current_condition[0]
                    weatherTemp = c.temp_F + "°F"
                    weatherDesc = c.weatherDesc[0].value
                    weatherCity = d.nearest_area?.[0]?.areaName?.[0]?.value ?? ""
                    weatherIcon = {
                        "113": "󰖨", "116": "⛅", "119": "󰖐", "122": "󰖐",
                        "176": "🌦", "179": "🌨", "182": "🌧", "185": "🌧",
                        "200": "⛈",  "227": "🌨", "230": "🌨", "248": "🌫",
                        "260": "🌫", "293": "🌧", "296": "🌧", "299": "🌧",
                        "302": "🌧", "305": "🌧", "308": "🌧", "311": "🌧",
                        "314": "🌧", "317": "🌧", "320": "🌨", "323": "🌨",
                        "326": "🌨", "329": "❄",  "332": "❄",  "335": "❄",
                        "338": "❄",  "350": "🌧", "353": "🌧", "356": "🌧",
                        "359": "🌧", "362": "🌧", "365": "🌧", "368": "🌨",
                        "371": "🌨", "374": "🌧", "377": "🌧", "386": "⛈",
                        "389": "⛈",  "392": "⛈",  "395": "❄",
                    }[c.weatherCode] ?? "󰖐"
                } catch(e) { weatherDesc = "Unavailable" }
            } else { weatherDesc = "Unavailable" }
        }
        xhr.open("GET", "https://wttr.in/?format=j1")
        xhr.send()
    }

    // -------------------------------------------------------------------------
    // Calendar state
    // -------------------------------------------------------------------------
    property date _calDate: new Date()
    readonly property int _calYear:  _calDate.getFullYear()
    readonly property int _calMonth: _calDate.getMonth()

    readonly property var _calDays: {
        const first = new Date(_calYear, _calMonth, 1).getDay()  // 0=Sun
        const total = new Date(_calYear, _calMonth + 1, 0).getDate()
        const today = new Date()
        const result = []
        for (let i = 0; i < first; i++) result.push({ day: 0, isToday: false })
        for (let d = 1; d <= total; d++) {
            const isToday = today.getFullYear() === _calYear && today.getMonth() === _calMonth && today.getDate() === d
            result.push({ day: d, isToday })
        }
        return result
    }

    readonly property var _monthNames: ["January","February","March","April","May","June","July","August","September","October","November","December"]

    // Now-playing: first active player
    readonly property var _player: {
        const players = Mpris.players.values ?? []
        return players.find(p => p.playbackState === MprisPlaybackState.Playing) ?? players[0] ?? null
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Constants.innerPadding * 2
        spacing: Constants.innerPadding * 2

        // Left column: time + weather + now playing
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.4
            spacing: Constants.innerPadding * 2

            // Time block
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatTime(Time.date, "hh:mm")
                    color: Constants.nord6
                    font.family: Constants.font.family
                    font.pointSize: 52
                    font.bold: true
                    renderType: Text.NativeRendering
                    horizontalAlignment: Text.AlignLeft
                }
                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDate(Time.date, "dddd, MMMM d")
                    color: Constants.nord4
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.normalSize
                    renderType: Text.NativeRendering
                }
            }

            // Weather block
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: weatherRow.implicitHeight + Constants.innerPadding * 2
                radius: Constants.radius
                color: Constants.alpha(Constants.nord2, 0.6)

                RowLayout {
                    id: weatherRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Constants.innerPadding }
                    spacing: Constants.innerPadding

                    Text {
                        text: root.weatherIcon
                        font.family: Constants.font.family
                        font.pointSize: 28
                        renderType: Text.NativeRendering
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.weatherTemp
                            color: Constants.nord6
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.normalSize
                            renderType: Text.NativeRendering
                        }
                        Text {
                            text: root.weatherDesc + (root.weatherCity ? " - " + root.weatherCity : "")
                            color: Constants.nord4
                            font.family: Constants.font.family
                            font.pointSize: Constants.font.smallSize
                            renderType: Text.NativeRendering
                        }
                    }

                    ClickText {
                        text: "󰑖"
                        defaultColor: Constants.nord3
                        hoverColor: Constants.nord8
                        font.pointSize: Constants.font.iconSize
                        onClicked: root.fetchWeather()
                    }
                }
            }

            // Now playing
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: nowPlayingCol.implicitHeight + Constants.innerPadding * 2
                radius: Constants.radius
                color: Constants.alpha(Constants.nord2, 0.6)
                visible: root._player !== null

                ColumnLayout {
                    id: nowPlayingCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Constants.innerPadding }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.innerPadding

                        Rectangle {
                            width: 48; height: 48
                            radius: 6
                            color: Constants.alpha(Constants.nord1, 0.8)
                            clip: true

                            Text {
                                anchors.centerIn: parent
                                text: root._player?.playbackState === MprisPlaybackState.Playing ? "󰝚" : "󰝛"
                                color: Constants.nord8
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.iconSize
                                renderType: Text.NativeRendering
                                visible: artImg.status !== Image.Ready
                            }

                            Image {
                                id: artImg
                                anchors.fill: parent
                                source: root._player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                width: parent.width
                                text: root._player?.trackTitle ?? "Nothing playing"
                                color: Constants.nord6
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                            Text {
                                width: parent.width
                                text: root._player?.trackArtist ?? ""
                                color: Constants.nord4
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                            Text {
                                width: parent.width
                                text: root._player?.trackAlbum ?? ""
                                color: Constants.nord3
                                font.family: Constants.font.family
                                font.pointSize: Constants.font.smallSize - 2
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                                visible: text.length > 0
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Constants.innerPadding

                        Repeater {
                            model: [
                                { icon: "󰒫", action: () => root._player?.previous() },
                                { icon: root._player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊", action: () => root._player?.playbackState === MprisPlaybackState.Playing ? root._player?.pause() : root._player?.play() },
                                { icon: "󰒬", action: () => root._player?.next() },
                            ]
                            delegate: ClickText {
                                required property var modelData
                                text: modelData.icon
                                hoverColor: Constants.nord8
                                font.pointSize: Constants.font.iconSize
                                onClicked: modelData.action()
                            }
                        }
                    }
                }
            }

            Divider { opacity: 0.35 }

            // Brightness
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

                    HSlider {
                        Layout.fillWidth: true
                        value: root.brightness / Math.max(root.maxBrightness, 1)
                        fillColor: Constants.nord13
                        trackHeight: 8
                        handleSize: 16
                        onMoved: v => root.setBrightness(Math.round(v * root.maxBrightness))
                    }

                    Text { text: "󰃠"; color: Constants.nord13; font.family: Constants.font.family; font.pointSize: Constants.font.iconSize; renderType: Text.NativeRendering }

                    Text {
                        text: Math.round(root.brightness / Math.max(root.maxBrightness, 1) * 100) + "%"
                        color: Constants.nord6; font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering
                        Layout.minimumWidth: 40
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: [10, 25, 50, 75, 100]
                        ChipButton {
                            required property int modelData
                            label: modelData + "%"
                            tint: Math.round(root.brightness / Math.max(root.maxBrightness, 1) * 100) === modelData
                                  ? Constants.nord8 : Constants.nord4
                            onClicked: root.setBrightness(Math.round(modelData / 100 * root.maxBrightness))
                        }
                    }
                }
            }

            // Audio output
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
                    ClickText {
                        text: "more >"
                        defaultColor: Constants.nord3
                        hoverColor: Constants.nord8
                        font.pointSize: Constants.font.smallSize - 2
                        onClicked: DashboardState.switchTab("audio")
                    }
                }

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

        // Right column: calendar
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            // Month navigation
            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.innerPadding

                ClickText {
                    text: "󰅁"
                    hoverColor: Constants.nord8
                    font.pointSize: Constants.font.iconSize
                    onClicked: root._calDate = new Date(root._calYear, root._calMonth - 1, 1)
                }

                Text {
                    Layout.fillWidth: true
                    text: root._monthNames[root._calMonth] + " " + root._calYear
                    color: Constants.nord6; font.family: Constants.font.family
                    font.pointSize: Constants.font.normalSize
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                ClickText {
                    text: "󰅂"
                    hoverColor: Constants.nord8
                    font.pointSize: Constants.font.iconSize
                    onClicked: root._calDate = new Date(root._calYear, root._calMonth + 1, 1)
                }
            }

            // Day-of-week header
            Grid {
                columns: 7; Layout.fillWidth: true; spacing: 2
                Repeater {
                    model: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                    Text {
                        required property string modelData
                        width: (parent.width - 12) / 7
                        text: modelData; color: Constants.nord3
                        font.family: Constants.font.family; font.pointSize: Constants.font.smallSize - 2
                        horizontalAlignment: Text.AlignHCenter; renderType: Text.NativeRendering
                    }
                }
            }

            // Day grid
            Grid {
                columns: 7; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 2
                Repeater {
                    model: root._calDays
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 12) / 7
                        height: width; radius: width / 2
                        color: modelData.isToday ? Constants.nord8 : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.day > 0 ? parent.modelData.day : ""
                            color: parent.modelData.isToday ? Constants.nord0 : Constants.nord4
                            font.family: Constants.font.family; font.pointSize: Constants.font.smallSize - 2
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
