import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

BarContainer {
    id: root

    width: contents.implicitWidth + 2 * Constants.innerPadding
    color: Constants.nord3

    RowLayout {
        id: contents
        anchors.fill: parent
        anchors.margins: Constants.innerPadding
        spacing: 2

        // Toggle
        Item {
            implicitHeight: parent.height
            implicitWidth: implicitHeight

            IconText {
                anchors.centerIn: parent
                text: "󰖟"
                color: ProxyState.active ? Constants.nord14 : Constants.nord4
                opacity: toggleArea.containsMouse ? 0.7 : 1
                Behavior on color { CAnim {} }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ProxyState.toggle()
            }
        }

        Item {
            implicitHeight: parent.height
            implicitWidth: ProxyState.active ? implicitHeight : 0
            visible: ProxyState.active
            clip: true

            Behavior on implicitWidth { NumberAnimation { duration: Constants.animDurations.normal / 2; easing.type: Easing.BezierSpline; easing.bezierCurve: Constants.animCurves.standard } }

            ClickText {
                anchors.fill: parent
                text: "󰜉"
                defaultColor: Constants.nord4
                hoverColor: Constants.nord13
                font.pointSize: Constants.font.iconSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                onClicked: ProxyState.restart()
            }
        }
    }
}
