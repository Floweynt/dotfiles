pragma ComponentBehavior: Bound

import QtQuick
import qs 

Text {
    id: root

    property bool animate: false
    property string animateProp: "scale"
    property real animateFrom: 0
    property real animateTo: 1
    property int animateDuration: Constants.animDurations.normal

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Constants.nord6
    font.family: Constants.font.family
    font.pointSize: Constants.font.normalSize

    Behavior on color {
        CAnim {}
    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            Anim {
                to: root.animateFrom
                easing.bezierCurve: Constants.animCurves.standardAccel
            }
            PropertyAction {}
            Anim {
                to: root.animateTo
                easing.bezierCurve: Constants.animCurves.standardDecel
            }
        }
    }

    component Anim: NumberAnimation {
        target: root
        property: root.animateProp
        duration: root.animateDuration / 2
        easing.type: Easing.BezierSpline
    }
}
