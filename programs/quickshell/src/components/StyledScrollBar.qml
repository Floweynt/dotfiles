import QtQuick
import QtQuick.Controls
import qs

ScrollBar {
    policy: ScrollBar.AsNeeded
    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Constants.nord3; opacity: 0.6 }
}
