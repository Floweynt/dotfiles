import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Rectangle {
    id: root

    property string label: ""
    property string icon: ""
    property bool active: false
    signal toggled()

    implicitWidth: row.implicitWidth + Constants.innerPadding * 2
    implicitHeight: 30
    radius: Constants.radius
    color: active ? Qt.rgba(Constants.nord8.r, Constants.nord8.g, Constants.nord8.b, 0.2)
                  : Qt.rgba(Constants.nord2.r, Constants.nord2.g, Constants.nord2.b, 0.8)
    border.color: active ? Constants.nord8 : "transparent"
    border.width: 1
    Behavior on color { CAnim {} }
    Behavior on border.color { CAnim {} }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.icon
            color: root.active ? Constants.nord8 : Constants.nord4
            font.family: Constants.font.family
            font.pointSize: Constants.font.smallSize
            renderType: Text.NativeRendering
            Behavior on color { CAnim {} }
        }

        Text {
            text: root.label
            color: root.active ? Constants.nord8 : Constants.nord4
            font.family: Constants.font.family
            font.pointSize: Constants.font.smallSize
            renderType: Text.NativeRendering
            Behavior on color { CAnim {} }
        }
    }

    scale: 1.0
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed:  root.scale = 0.88
        onReleased: root.scale = 1.0
        onClicked:  root.toggled()
    }
}
