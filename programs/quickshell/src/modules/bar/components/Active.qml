pragma ComponentBehavior: Bound

import qs.components
import qs.services
import QtQuick
import qs

Item {
    id: root

    property color colour: Constants.nord8
    required property int maxWidth
    property Title current: text1

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: icon.implicitWidth + current.implicitWidth + Constants.innerPadding
    implicitHeight: Math.max(icon.implicitHeight, current.implicitHeight)

    IconText {
        id: icon

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        animate: true
        text: Constants.icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, Constants.icons.desktopIcon)
        color: Constants.nord8
        font.pointSize: Constants.font.bigIconSize
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        text: Hypr.activeToplevel?.title ?? "Desktop"
        font.pointSize: Constants.font.normalSize
        font.family: Constants.font.family
        elide: Qt.ElideRight

        // available width for the text (subtract icon width and spacing)
        elideWidth: Math.max(0, root.maxWidth)

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitWidth {
        Anim {
            easing.bezierCurve: Constants.animCurves.emphasized
        }
    }

    component Title: BarText {
        id: text

        // place title to the right of the icon, centered vertically
        anchors.left: icon.right
        anchors.leftMargin: Constants.innerPadding
        anchors.verticalCenter: icon.verticalCenter

        font.pointSize: metrics.font.pointSize
        font.family: metrics.font.family
        color: Constants.nord8
        opacity: root.current === this ? 1 : 0

        // normal horizontal layout (no rotation)
        width: implicitWidth
        height: implicitHeight

        Behavior on opacity {
            Anim {}
        }
    }
}
