pragma ComponentBehavior: Bound

import qs.components
import qs.services
import QtQuick
import qs
import Quickshell.Services.Notifications
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell

BarRect {
    id: root
    required property Notifs.Notif modelData
    border.color: modelData.urgency == NotificationUrgency.Critical ? Constants.nord12 : Constants.nord7
    border.width: Constants.notifBorderRadius
    color: Constants.nord1
    implicitWidth: 500
    implicitHeight: Math.max(contents.implicitHeight, 50) + 2 * Constants.outerPadding
    property bool expanded: false

    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        width: Constants.font.iconSize + 2 * Constants.innerPadding
        height: Constants.font.iconSize + 2 * Constants.innerPadding
        IconText {
            animate: true
            anchors.centerIn: parent
            text: root.expanded ? "󰅃" : "󰅀"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.expanded = !root.expanded;
            }
        }
    }

    RowLayout {
        id: contents
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Constants.outerPadding

        Loader {
            asynchronous: true
            enabled: root.modelData.appIcon != ""
            Layout.alignment: Qt.AlignVCenter

            sourceComponent: IconImage {
                anchors.fill: parent
                source: Quickshell.iconPath(root.modelData.appIcon)
                implicitHeight: 10
                asynchronous: true
            }
        }

        ColumnLayout {
            // wtf evil magic numbers
            spacing: -6

            BarText {
                id: appName
                text: appNameMetrics.elidedText
                font.pointSize: Constants.font.smallSize
                color: Constants.nord4

                TextMetrics {
                    id: appNameMetrics

                    text: root.modelData.appName
                    font.family: appName.font.family
                    font.pointSize: appName.font.pointSize
                    elide: Text.ElideRight
                    elideWidth: 450
                }
            }

            RowLayout {
                BarText {
                    id: summary
                    text: summaryMetrics.elidedText
                    color: Constants.nord6

                    TextMetrics {
                        id: summaryMetrics

                        text: root.modelData.summary
                        font.family: summary.font.family
                        font.pointSize: summary.font.pointSize
                        elide: Text.ElideRight
                        elideWidth: 300
                    }
                }

                IconText {
                    text: ""
                    color: Constants.nord4
                }

                BarText {
                    font.pointSize: Constants.font.smallSize
                    text: root.modelData.timeStr
                    color: Constants.nord4
                }
            }

            Item {
                implicitHeight: body.height
                BarText {
                    id: body
                    text: root.expanded ? bodyMetrics.text : bodyMetrics.elidedText
                    font.pointSize: Constants.font.smallSize
                    color: Constants.nord4
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    width: 450

                    TextMetrics {
                        id: bodyMetrics

                        text: root.modelData.body
                        font.family: body.font.family
                        font.pointSize: body.font.pointSize
                        elide: Text.ElideRight
                        elideWidth: body.width
                    }
                }
            }
        }
    }
}
