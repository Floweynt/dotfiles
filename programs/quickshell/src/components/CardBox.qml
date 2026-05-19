import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: root
    default property alias contents: col.data
    property int spacing: 6

    radius: Constants.radius
    color: Constants.alpha(Constants.nord2, 0.5)
    implicitHeight: col.implicitHeight + Constants.innerPadding * 2

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Constants.innerPadding }
        spacing: root.spacing
    }
}
