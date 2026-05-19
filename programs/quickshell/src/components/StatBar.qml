import QtQuick
import qs

Item {
    id: root
    property real value: 0
    property color fillColor: Constants.nord8
    property int trackHeight: 6

    implicitHeight: trackHeight

    Rectangle {
        anchors.fill: parent
        radius: root.trackHeight / 2
        color: Constants.nord1

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: root.fillColor
            Behavior on width { NumberAnimation { duration: 300 } }
            Behavior on color { CAnim {} }
        }
    }
}
