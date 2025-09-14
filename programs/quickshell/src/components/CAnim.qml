import QtQuick
import qs

ColorAnimation {
    duration: Constants.animDurations.normal 
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Constants.animCurves.standard
}
