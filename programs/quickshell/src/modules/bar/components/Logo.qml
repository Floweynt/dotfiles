import Quickshell.Widgets
import QtQuick
import Quickshell
import qs
import qs.services

Item {
    anchors.margins: Constants.innerPadding
    anchors.top: parent.top
    anchors.left: parent.left
    width: height

    IconImage {
        anchors.centerIn: parent
        source: Quickshell.iconPath("nix-snowflake", true)
        implicitSize: parent.height * 0.7
        opacity: clickArea.containsMouse ? 0.7 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: LauncherState.toggle()
    }
}
