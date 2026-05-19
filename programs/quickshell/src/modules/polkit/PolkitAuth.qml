pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs
import qs.components
import qs.floweyshell 1.0

PanelWindow {
    id: root

    WlrLayershell.namespace:     `${Constants.name}-polkit`
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: PolkitAgent.active
                                     ? WlrKeyboardFocus.OnDemand
                                     : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    color:   "transparent"
    visible: PolkitAgent.active

    anchors { top: true; bottom: true; left: true; right: true }

    property bool _shown: false

    Timer {
        id: showTimer; interval: 16
        onTriggered: { root._shown = true; passwordField.forceActiveFocus() }
    }

    Connections {
        target: PolkitAgent
        function onActiveChanged() {
            if (PolkitAgent.active) {
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
        color:   Constants.nord0
        opacity: root._shown ? 0.75 : 0
        Behavior on opacity { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.standard } }
        MouseArea { anchors.fill: parent } // swallow clicks
    }

    // Auth card
    BarRect {
        id: card
        anchors.centerIn: parent
        width:   440
        height:  content.implicitHeight + Constants.outerPadding * 2
        color:   Constants.nord1
        opacity: root._shown ? 1.0 : 0.0
        scale:   root._shown ? 1.0 : 0.95
        Behavior on opacity { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.emphasizedDecel } }
        Behavior on scale   { NumberAnimation { duration: Constants.animDurations.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.emphasizedDecel } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowBlur: 0.5; shadowColor: "#000000"
            shadowOpacity: 0.7; shadowVerticalOffset: 16
        }

        MouseArea { anchors.fill: parent } // swallow clicks

        ColumnLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Constants.outerPadding }
            spacing: Constants.innerPadding

            Text {
                text: "  Authentication Required"
                color: Constants.nord8
                font.family: Constants.font.family
                font.pointSize: Constants.font.normalSize
                font.bold: true
                renderType: Text.NativeRendering
            }

            Divider { opacity: 0.5 }

            Text {
                Layout.fillWidth: true
                text: PolkitAgent.message
                color: Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                renderType: Text.NativeRendering
            }

            Text {
                text: "Authenticate as  " + PolkitAgent.user
                color: Constants.nord9
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                renderType: Text.NativeRendering
            }

            // Fingerprint
            Rectangle {
                id: fpRect
                Layout.fillWidth: true
                visible: PolkitAgent.fingerprintAvailable
                height: 38
                radius: Constants.radius

                readonly property bool isError: {
                    const s = PolkitAgent.fingerprintStatus
                    return s !== "" && s !== "Swipe your finger"
                }

                color:        fpRect.isError
                    ? Constants.alpha(Constants.nord11, 0.08)
                    : Constants.alpha(Constants.nord9, 0.08)
                border.color: fpRect.isError
                    ? Constants.alpha(Constants.nord11, 0.40)
                    : Constants.alpha(Constants.nord9, 0.40)
                border.width: 1
                Behavior on color        { CAnim {} }
                Behavior on border.color { CAnim {} }

                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    spacing: 8
                    Text {
                        text: ""
                        color: fpRect.isError ? Constants.nord11 : Constants.nord9
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.normalSize
                        renderType: Text.NativeRendering
                        Behavior on color { CAnim {} }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: PolkitAgent.fingerprintStatus
                        elide: Text.ElideRight
                        color: fpRect.isError ? Constants.nord11 : Constants.nord9
                        font.family: Constants.font.family
                        font.pointSize: Constants.font.smallSize
                        renderType: Text.NativeRendering
                        Behavior on color { CAnim {} }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: PolkitAgent.fingerprintAvailable
                spacing: 8
                Divider {}
                Text {
                    text: "or"
                    color: Constants.nord3
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize
                    renderType: Text.NativeRendering
                }
                Divider {}
            }

            // Password field
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: Constants.radius
                color: Constants.alpha(Constants.nord0, 0.8)
                border.color: passwordField.activeFocus ? Constants.nord8 : Constants.nord3
                border.width: 1
                Behavior on border.color { CAnim {} }

                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "Password..."
                    color: Constants.nord3
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize
                    renderType: Text.NativeRendering
                    visible: passwordField.text.length === 0 && !passwordField.activeFocus
                }

                TextInput {
                    id: passwordField
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                    echoMode: TextInput.Password
                    color: Constants.nord6
                    font.family: Constants.font.family
                    font.pointSize: Constants.font.smallSize
                    renderType: Text.NativeRendering
                    enabled: PolkitAgent.active && !PolkitAgent.busy
                    Keys.onReturnPressed: if (!PolkitAgent.busy && text.length > 0)
                        PolkitAgent.authenticate(PolkitAgent.cookie, text)
                }
            }

            Text {
                Layout.fillWidth: true
                visible: PolkitAgent.lastError.length > 0
                text: "  " + PolkitAgent.lastError
                color: Constants.nord11
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                renderType: Text.NativeRendering

                Connections {
                    target: PolkitAgent
                    function onLastErrorChanged() {
                        if (PolkitAgent.lastError.length > 0) {
                            passwordField.selectAll()
                            passwordField.forceActiveFocus()
                        }
                    }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.innerPadding
                Item { Layout.fillWidth: true }

                // Cancel
                ChipButton {
                    label: "Cancel"
                    tint: Constants.nord11
                    busy: PolkitAgent.busy
                    onClicked: PolkitAgent.cancel(PolkitAgent.cookie)
                }

                // Authenticate
                ChipButton {
                    label: PolkitAgent.busy ? "Authenticating..." : "Authenticate"
                    tint: Constants.nord8
                    busy: PolkitAgent.busy || passwordField.text.length === 0
                    onClicked: PolkitAgent.authenticate(PolkitAgent.cookie, passwordField.text)
                }
            }

            Item { height: 0 } // bottom breathing room handled by outer margin
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: PolkitAgent.active && !PolkitAgent.busy
        onActivated: PolkitAgent.cancel(PolkitAgent.cookie)
    }

    // Clear the password field whenever the dialog closes
    onVisibleChanged: { if (!visible) passwordField.text = "" }
}
