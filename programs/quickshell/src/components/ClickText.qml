import QtQuick
import qs

Text {
    id: root

    property color defaultColor: Constants.nord4
    property color hoverColor: defaultColor
    signal clicked()

    color: ma.containsMouse ? hoverColor : defaultColor
    font.family: Constants.font.family
    font.pointSize: Constants.font.smallSize
    renderType: Text.NativeRendering

    Behavior on color   { CAnim {} }
    Behavior on opacity { NumberAnimation { duration: 80 } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed:  root.opacity = 0.55
        onReleased: root.opacity = 1.0
        onCanceled: root.opacity = 1.0
        onClicked: root.clicked()
    }
}
