import QtQuick
import qs

Rectangle {
    id: root
    property string label: ""
    property string icon: ""
    property color tint: Constants.nord4
    property bool active: false
    property bool busy: false
    signal clicked()
    signal toggled()

    readonly property color _tint: active ? Constants.nord8 : tint

    implicitWidth: chipRow.implicitWidth + 16
    implicitHeight: 26
    radius: Constants.radius
    opacity: root.busy ? 0.4 : 1.0
    color: Constants.alpha(_tint, ma.containsMouse ? 0.22 : 0.12)
    border.color: Constants.alpha(_tint, ma.containsMouse ? 0.6 : 0.35)
    border.width: 1
    scale: 1.0

    Behavior on scale   { NumberAnimation { duration: 80;  easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on color   { CAnim {} }
    Behavior on border.color { CAnim {} }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 4
        Text { text: root.icon; color: root._tint; font.family: Constants.font.family; font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering }
        Text { text: root.label; color: root._tint; font.family: Constants.font.family; font.pointSize: Constants.font.smallSize; renderType: Text.NativeRendering }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: !root.busy
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.scale = 0.88
        onReleased: root.scale = 1.0
        onClicked: { root.clicked(); root.toggled() }
    }
}
