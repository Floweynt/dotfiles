pragma ComponentBehavior: Bound

import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.components
import qs

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

            TopBar {
                id: topBar
                screen: win.screen
                window: win
                popupHolder: popupHolder
            }

            PopupHolder {
                id: popupHolder
                anchors.top: topBar.bottom
                anchors.bottom: winDummy.bottom
                anchors.margins: Constants.outerPadding
                x: Constants.outerPadding
                width: win.width - 2 * Constants.outerPadding

                property Region theRegion: Region {}

                onActiveItemChanged: {
                    if(activeItem != null) {
                        theRegion.item = activeItem
                        win.mask.regions.push(theRegion)
                    } else {
                        const index = win.mask.regions.indexOf(theRegion)
                        if(index != -1) {
                            win.mask.regions.splice(index, 1)
                        }
                    }
                }
            }
        }
    }

    /*
            Variants {
                id: regions

                model: panels.children

                Region {
                    required property Item modelData

                    x: modelData.x + bar.implicitWidth
                    y: modelData.y + Config.border.thickness
                    width: modelData.width
                    height: modelData.height
                    intersection: Intersection.Subtract
                }
            }

            HyprlandFocusGrab {
                active: (visibilities.launcher && Config.launcher.enabled) || (visibilities.session && Config.session.enabled)
                windows: [win]
                onCleared: {
                    visibilities.launcher = false;
                    visibilities.session = false;
                }
            }*/
}
