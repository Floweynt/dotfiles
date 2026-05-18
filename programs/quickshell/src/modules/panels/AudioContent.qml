pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components

Item {
    id: root

    // Bind all nodes so audio properties are accessible
    PwObjectTracker {
        objects: Pipewire.nodes.values ?? []
    }

    property int tab: 0  // 0 = Output, 1 = Input, 2 = Streams

    property var hwSinks: (Pipewire.nodes.values ?? []).filter(n => !n.isStream && n.isSink && n.ready)
    property var hwSources: (Pipewire.nodes.values ?? []).filter(n => !n.isStream && !n.isSink && n.ready && n.properties?.["media.class"] === "Audio/Source")
    property var streams: (Pipewire.nodes.values ?? []).filter(n => n.isStream && n.isSink && n.ready)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.innerPadding
        spacing: Constants.innerPadding

        // Tab bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: ["Output", "Input", "Streams"]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 30
                    radius: Constants.radius
                    color: root.tab === index ? Constants.nord8 : Constants.nord2
                    Behavior on color { CAnim {} }

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: root.tab === parent.index ? Constants.nord0 : Constants.nord4
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        Behavior on color { CAnim {} }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = parent.index
                    }
                }
            }
        }

        // Content
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            acceptedButtons: Qt.NoButton

            model: root.tab === 0 ? root.hwSinks
                 : root.tab === 1 ? root.hwSources
                 : root.streams

            delegate: AudioNodeRow {
                required property var modelData
                node: modelData
                isDefault: tab === 0
                    ? (Pipewire.defaultAudioSink && modelData.id === Pipewire.defaultAudioSink.id)
                    : tab === 1
                    ? (Pipewire.defaultAudioSource && modelData.id === Pipewire.defaultAudioSource.id)
                    : false
                onSetDefault: {
                    if (root.tab === 0) Pipewire.preferredDefaultAudioSink = modelData
                    else if (root.tab === 1) Pipewire.preferredDefaultAudioSource = modelData
                }
                width: list.width
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Constants.nord3; opacity: 0.6 }
            }
        }
    }
}
