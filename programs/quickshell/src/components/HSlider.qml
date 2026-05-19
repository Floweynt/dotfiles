import QtQuick
import qs
import qs.components

Rectangle {
    id: root
    property real value: 0
    property color fillColor: Constants.nord8
    property int trackHeight: 6
    property int handleSize: 14
    signal moved(real v)

    height: trackHeight
    radius: trackHeight / 2
    color: Constants.nord2

    Rectangle {
        width: root.width * root.value
        height: parent.height; radius: parent.radius
        color: root.fillColor
        Behavior on width { NumberAnimation { duration: 80 } }
        Behavior on color { CAnim {} }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeHorCursor
        preventStealing: true
        onClicked: mouse => root.moved(Math.max(0, Math.min(1, mouse.x / root.width)))
        onPositionChanged: mouse => { if (pressed) root.moved(Math.max(0, Math.min(1, mouse.x / root.width))) }
    }

    Rectangle {
        id: handle
        width: root.handleSize; height: root.handleSize; radius: width / 2
        x: Math.max(0, Math.min(root.width - width, root.width * root.value - width / 2))
        y: (root.height - height) / 2
        color: handleMA.pressed ? Constants.nord8 : Constants.nord6
        border.color: handleMA.pressed ? Constants.nord8 : Constants.nord3
        border.width: 1
        Behavior on color { CAnim {} }
        Behavior on border.color { CAnim {} }

        MouseArea {
            id: handleMA
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor
            preventStealing: true
            onPositionChanged: mouse => {
                if (pressed) {
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    root.moved(Math.max(0, Math.min(1, pt.x / root.width)))
                }
            }
        }
    }
}
