import QtQuick
import Quickshell
import qs
import QtQuick.Effects 

Rectangle {
    required property ShellScreen screen
    required property PanelWindow window

    x: Constants.outerPadding
    width: screen.width - 2 * Constants.outerPadding
    color: Constants.nord1
    radius: Constants.radius
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 20
        shadowColor: Qt.alpha(Constants.nord4, 1)
    }
    /*Text {
        id: helloText
        text: "Hello world!"
        y: 30
        anchors.horizontalCenter: page.horizontalCenter
        font.pointSize: 24; font.bold: true
    }*/
}
