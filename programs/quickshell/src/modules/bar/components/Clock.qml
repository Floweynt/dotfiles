import QtQuick.Layouts
import QtQuick
import qs
import qs.components
import qs.services

BarContainer {
    id: root 

    width: contents.implicitWidth + 2 * Constants.innerPadding
    color: Constants.nord3

    RowLayout {
        id: contents
        anchors.fill: parent
        anchors.margins: Constants.innerPadding

        BarText {
            text: Time.format("hh:mm")
            animate: true
            color: Constants.nord6
        }

        BarText {
            text: Time.format("ss")
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
            text: Time.format("MM")
            animate: true
            color: Constants.nord6
        }

        BarText {
            text: Time.format("dd")
            animate: true
            color: Constants.nord6
        }
    }
}
