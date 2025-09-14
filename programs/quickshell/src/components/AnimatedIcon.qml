pragma ComponentBehavior: Bound
import Quickshell.Widgets
import qs
import QtQuick

IconImage {
    id: root
    asynchronous: true
    implicitSize: parent.implicitHeight

    property int animateDuration: Constants.animDurations.normal

    Behavior on source {
        SequentialAnimation {
            Anim {
                onStarted: {
                    print("hi")
                }
                to: 0
                easing.bezierCurve: Constants.animCurves.standardAccel
            }
            PropertyAction {}
            Anim {
                to: parent.implicitHeight
                easing.bezierCurve: Constants.animCurves.standardDecel
            }
        }
    }

    component Anim: NumberAnimation {
        target: root
        property: "implicitSize"
        duration: root.animateDuration / 2
        easing.type: Easing.BezierSpline
    }
}
