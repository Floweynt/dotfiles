pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.components

PanelWindow {
    id: root

    WlrLayershell.namespace: `${Constants.name}-panel`
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: PanelState.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    color: "transparent"
    visible: PanelState.visible

    anchors { top: true; bottom: true; left: true; right: true }

    property bool _shown: false

    Timer {
        id: showTimer
        interval: 16
        onTriggered: root._shown = true
    }

    Connections {
        target: PanelState
        function onVisibleChanged() {
            if (PanelState.visible) {
                root._shown = false
                showTimer.start()
            } else {
                root._shown = false
            }
        }
    }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Constants.nord0
        opacity: root._shown ? 0.82 : 0
        Behavior on opacity { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.standard } }
        MouseArea { anchors.fill: parent; onClicked: PanelState.close() }
    }

    // Panel card
    BarRect {
        id: card
        anchors.centerIn: parent
        width: parent.width * 0.55
        height: parent.height * 0.65
        color: Constants.nord1
        opacity: root._shown ? 1 : 0
        scale: root._shown ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.emphasizedDecel } }
        Behavior on scale   { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.emphasizedDecel } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowBlur: 0.5; shadowColor: "#000000"; shadowOpacity: 0.55; shadowVerticalOffset: 10
        }

        // Title bar
        Rectangle {
            id: titleBar
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Constants.innerPadding }
            height: Constants.barHeight
            radius: Constants.radius
            color: Constants.nord2

            Text {
                anchors { left: parent.left; leftMargin: Constants.innerPadding; verticalCenter: parent.verticalCenter }
                text: {
                    if (PanelState.panel === "audio")     return "󰽴  Audio"
                    if (PanelState.panel === "bluetooth") return "󰂯  Bluetooth"
                    if (PanelState.panel === "net")       return "󱋊  Network"
                    return ""
                }
                color: Constants.nord6
                font.family: Constants.font.family
                font.pointSize: Constants.font.normalSize
                renderType: Text.NativeRendering
            }

            // Close button
            Text {
                anchors { right: parent.right; rightMargin: Constants.innerPadding; verticalCenter: parent.verticalCenter }
                text: "󰅖"
                color: closeArea.containsMouse ? Constants.nord11 : Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.iconSize
                renderType: Text.NativeRendering
                Behavior on color { CAnim {} }
                MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PanelState.close() }
            }
        }

        // Divider
        Rectangle {
            id: divider
            anchors { top: titleBar.bottom; left: parent.left; right: parent.right; leftMargin: Constants.innerPadding; rightMargin: Constants.innerPadding }
            height: 1; color: Constants.nord3; opacity: 0.45
        }

        // Content area — load appropriate panel
        Loader {
            anchors { top: divider.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 0 }
            active: PanelState.visible
            sourceComponent: {
                if (PanelState.panel === "audio")     return audioComp
                if (PanelState.panel === "bluetooth") return btComp
                if (PanelState.panel === "net")       return netComp
                return null
            }
        }

        Component { id: audioComp;  AudioContent  {} }
        Component { id: btComp;     BluetoothContent {} }
        Component { id: netComp;    NetworkContent {} }
    }

    Keys.onEscapePressed: PanelState.close()
}
