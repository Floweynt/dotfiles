pragma ComponentBehavior: Bound

import QtQuick
import qs

Item {
    id: root
    required property PopupHolder holder
    default property Item innerChild

    anchors.fill: parent

    Timer {
        id: hoverStateTimer
        interval: 100
        repeat: false
        running: false
        onTriggered: {
            if (hoverArea.containsMouse || popupHoverArea.containsMouse) {
                return;
            }

            root.holder.activeItem = null;
            popup.height = 0;
            popup.y = popup.hiddenY
        }
    }

    function hoverStateChanged() {
        if (hoverArea.containsMouse || popupHoverArea.containsMouse) {
            popup.height = popup.targetHeight;
            popup.y = popup.targetY;
            holder.activeItem = popup;
        } else {
            hoverStateTimer.running = true;
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: {
            root.hoverStateChanged();
        }
    }

    BarRect {
        id: popup
        parent: root.holder
        width: Math.min(root.holder.width, root.innerChild.width)
        height: 0
        readonly property real targetHeight: Math.min(root.holder.height, root.innerChild.height)
        readonly property real hiddenY: root.parent.mapToGlobal(0, 0).y > (root.holder.y + root.holder.height / 2) ? root.holder.height : 0
        readonly property real targetY: root.parent.mapToGlobal(0, 0).y > (root.holder.y + root.holder.height / 2) ? root.holder.height - targetHeight : 0
        readonly property real minX: 0
        readonly property real maxX: root.holder.width - width
        readonly property real preferredX: root.parent.mapToGlobal(0, 0).x + root.parent.width / 2 - width / 2

        x: Math.min(Math.max(minX, preferredX), maxX)

        // what is it closer to? y on top or y on bottom, or the parent's y?
        y: hiddenY

        color: Constants.nord1

        Behavior on height {
            Anim {}
        }

        Behavior on x {
            Anim {}
        }

        Behavior on y {
            Anim {}
        }

        Behavior on width {
            Anim {}
        }

        MouseArea {
            id: popupHoverArea
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                root.hoverStateChanged();
            }
        }
    }
}
