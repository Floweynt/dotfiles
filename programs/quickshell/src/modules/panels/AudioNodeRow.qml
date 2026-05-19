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
    color: isDefault ? Constants.alpha(Constants.nord10, 0.25)
                     : Constants.alpha(Constants.nord2, 0.5)
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
            ClickText {
                text: (root.node?.audio?.muted ?? false) ? "󰖁" : "󰕾"
                defaultColor: (root.node?.audio?.muted ?? false) ? Constants.nord11 : Constants.nord4
                font.pointSize: Constants.font.iconSize
                onClicked: {
                    if (root.node?.audio) root.node.audio.muted = !root.node.audio.muted
                }
            }

            Text {
                text: root.node?.audio ? Math.round((root.node.audio.volume ?? 0) * 100) + "%" : "-"
                color: Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                renderType: Text.NativeRendering
            }
        }

        HSlider {
            Layout.fillWidth: true
            value: root.node?.audio?.volume ?? 0
            fillColor: (root.node?.audio?.muted ?? false) ? Constants.nord3 : Constants.nord8
            onMoved: v => { if (root.node?.audio) root.node.audio.volume = v }
        }
    }
}
