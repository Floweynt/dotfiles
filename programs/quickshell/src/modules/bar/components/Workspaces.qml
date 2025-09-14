pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs
import qs.services
import QtQuick.Layouts

Item {
    id: root
    anchors.margins: Constants.innerPadding
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: container.implicitWidth

    BarRect {
        anchors.fill: container
        color: Constants.nord3
    }

    BarRect {
        id: activeDisplay
        property real currentWsIdx: Hypr.activeWsId - 1
        property Item rect: entries.itemAt(currentWsIdx)

        property point childPos: root.mapFromItem(rect, 0, 0)

        // janky as fuck
        x: childPos.x
        y: childPos.y
        height: rect?.height ?? 0
        width: rect?.height ?? 0
        color: Constants.nord8

        Behavior on x {
            Anim {
                easing.bezierCurve: Constants.animCurves.emphasized
            }
        }

        layer.enabled: true
    }

    Item {
        id: container
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: contents.implicitWidth + 2 * Constants.innerPadding

        RowLayout {
            id: contents
            anchors.fill: parent
            anchors.margins: Constants.innerPadding
            spacing: Constants.innerPadding

            Repeater {
                id: entries
                model: ["", "󰈹", "", "", "", "", "", "", ""]
                Item {
                    id: entry
                    required property int index
                    required property string modelData
                    implicitHeight: parent.height
                    implicitWidth: implicitHeight

                    property color color: Hypr.windowsByWorkspace[index + 1] ? Constants.nord6 : Constants.nord1

                    Loader {
                        active: entry.modelData == ""
                        anchors.fill: parent
                        sourceComponent: Item {
                            anchors.fill: parent

                            BarRect {
                                id: rect
                                anchors.centerIn: parent
                                width: Constants.radius
                                height: width
                                color: entry.color

                                Behavior on color {
                                    CAnim {}
                                }
                            }
                        }
                    }

                    Loader {
                        active: entry.modelData != ""
                        anchors.fill: parent
                        sourceComponent: Item {
                            anchors.fill: parent

                            IconText {
                                text: entry.modelData
                                anchors.centerIn: parent
                                color: entry.color
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Hypr.dispatch(`workspace ${entry.index + 1}`);
                        }
                    }
                }
            }
        }
    }
}
