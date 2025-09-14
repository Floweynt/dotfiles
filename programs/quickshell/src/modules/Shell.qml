pragma ComponentBehavior: Bound

import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.modules.bar 
import qs.modules.notif

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        BasicWindow {
            id: win
            screen: scope.modelData
            name: "bars"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            // TODO:
            // WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Region {
                intersection: Intersection.Combine
                regions: [
                    Region {
                        item: topBar
                    },
                    Region {
                        item: notifs
                    }
                ]
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                id: winDummy
                x: 0
                y: 0
                width: win.width
                height: win.height
            }

            Notifications {
                id: notifs
                anchors.top: topBar.bottom
                anchors.left: topBar.left
                anchors.topMargin: Constants.outerPadding
            }

            TopBar {
                id: topBar
                screen: win.screen
                window: win
            }
        }
    }
}
