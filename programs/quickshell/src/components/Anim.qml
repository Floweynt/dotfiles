import QtQuick
import qs;

NumberAnimation {
    duration: Constants.animDurations.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Constants.animCurves.standard
}
