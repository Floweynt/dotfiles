import Quickshell.Widgets
import QtQuick
import Quickshell
import qs

Item {
    anchors.margins: Constants.innerPadding
    anchors.top: parent.top
    anchors.left: parent.left
    width: height

    IconImage {
        anchors.centerIn: parent
        source: Quickshell.iconPath("nix-snowflake", true)
        implicitSize: parent.height * 0.7
    }
}
