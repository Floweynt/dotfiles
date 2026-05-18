pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Rectangle {
    id: root

    required property PwNode node
    property bool isDefault: false
    signal setDefault()

    implicitHeight: col.implicitHeight + Constants.innerPadding * 2
    radius: Constants.radius
    color: isDefault ? Qt.rgba(Constants.nord10.r, Constants.nord10.g, Constants.nord10.b, 0.25)
                     : Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.5)
    Behavior on color { CAnim {} }

    ColumnLayout {
        id: col
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            margins: Constants.innerPadding
        }
        spacing: 6

        // Name row
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.innerPadding

            // Default indicator / set-default button
            Rectangle {
                width: 8; height: 8
                radius: 4
                color: root.isDefault ? Constants.nord8 : "transparent"
                border.color: root.isDefault ? Constants.nord8 : Constants.nord3
                Behavior on color { CAnim {} }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!root.isDefault) root.setDefault()
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.node?.description || root.node?.name || ""
                color: Constants.nord6
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            // Mute toggle
            Text {
                text: (root.node?.audio?.muted ?? false) ? "󰖁" : "󰕾"
                color: (root.node?.audio?.muted ?? false) ? Constants.nord11 : Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.iconSize
                renderType: Text.NativeRendering
                Behavior on color { CAnim {} }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.node?.audio) root.node.audio.muted = !root.node.audio.muted
                    }
                }
            }

            // Volume percent
            Text {
                text: root.node?.audio ? Math.round((root.node.audio.volume ?? 0) * 100) + "%" : "—"
                color: Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                renderType: Text.NativeRendering
            }
        }

        // Volume slider
        Rectangle {
            id: volTrack
            Layout.fillWidth: true; height: 6; radius: 3; color: Constants.nord2

            Rectangle {
                width: volTrack.width * (root.node?.audio?.volume ?? 0)
                height: parent.height; radius: parent.radius
                color: (root.node?.audio?.muted ?? false) ? Constants.nord3 : Constants.nord8
                Behavior on width { NumberAnimation { duration: 80 } }
                Behavior on color { CAnim {} }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                preventStealing: true
                onClicked: mouse => {
                    if (root.node?.audio)
                        root.node.audio.volume = Math.max(0, Math.min(1, mouse.x / volTrack.width))
                }
                onPositionChanged: mouse => {
                    if (pressed && root.node?.audio)
                        root.node.audio.volume = Math.max(0, Math.min(1, mouse.x / volTrack.width))
                }
            }

            Rectangle {
                width: 14; height: 14; radius: 7
                x: Math.max(0, Math.min(volTrack.width - width, volTrack.width * (root.node?.audio?.volume ?? 0) - width / 2))
                y: (volTrack.height - height) / 2
                color: volHandleMA.pressed ? Constants.nord8 : Constants.nord6
                border.color: volHandleMA.pressed ? Constants.nord8 : Constants.nord3
                border.width: 1
                Behavior on color { CAnim {} }
                Behavior on border.color { CAnim {} }

                MouseArea {
                    id: volHandleMA
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    preventStealing: true
                    onPositionChanged: mouse => {
                        if (pressed && root.node?.audio) {
                            const pt = mapToItem(volTrack, mouse.x, mouse.y)
                            root.node.audio.volume = Math.max(0, Math.min(1, pt.x / volTrack.width))
                        }
                    }
                }
            }
        }
    }
}
