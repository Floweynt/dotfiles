import QtQuick
import qs
import qs.modules.bar.components

Bar {
    id: bar
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
}
