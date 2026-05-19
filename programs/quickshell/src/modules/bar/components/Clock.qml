import QtQuick.Layouts
import QtQuick
import qs
import qs.components
import qs.services

BarContainer {
    id: root

    readonly property var _time: Time

    width: contents.implicitWidth + 2 * Constants.innerPadding
    color: Constants.nord3

    RowLayout {
        id: contents
        anchors.fill: parent
        anchors.margins: Constants.innerPadding

        BarText {
            text: root._time.format("hh:mm")
            animate: true
            color: Constants.nord6
        }

        BarText {
            text: root._time.format("ss")
            renderType: Text.QtRendering
            color: Constants.nord4
        }

        Item {
            implicitHeight: parent.height
            implicitWidth: implicitHeight

            IconText {
                anchors.centerIn: parent
                text: "󰃭"
                color: Constants.nord7
            }
        }

        BarText {
            text: root._time.format("MM")
            animate: true
            color: Constants.nord6
        }

        BarText {
            text: root._time.format("dd")
            animate: true
            color: Constants.nord6
        }
    }
}
