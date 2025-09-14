import QtQuick
import qs
import qs.modules.bar.components
import qs.components

Bar {
    id: bar
    required property PopupHolder popupHolder
    screen: screen
    y: Constants.outerPadding
    height: Constants.topBarHeight

    BarExclusion {
        bar: bar
        anchors.top: true
    }

    Logo {
        id: logo
        anchors.bottom: bar.bottom
    }

    Workspaces {
        anchors.left: logo.right
    }

    Active {
        maxWidth: bar.width / 3
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Clock {
        id: clock
        anchors.right: parent.right
    }

    Perf {
        anchors.right: clock.left
    }

    /*Text {
        id: helloText
        text: "Hello world!"
        y: 30
        anchors.horizontalCenter: page.horizontalCenter
        font.pointSize: 24; font.bold: true
    }*/
}
