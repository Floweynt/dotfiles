pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // Uniform entry shape: { name, iconName, categories, description, keepOpen, run() }
    required property var entry
    property bool selected: false

    signal launched()
    signal hovered()

    implicitHeight: contentCol.implicitHeight + Constants.innerPadding * 2
    radius: Constants.radius

    // Use same RGB as nord2 for all states so CAnim only tweens alpha, not hue
    color: selected
        ? Constants.nord2
        : hover.containsMouse
            ? Constants.alpha(Constants.nord2, 0.45)
            : Constants.alpha(Constants.nord2, 0)

    Behavior on color { CAnim {} }

    Row {
        anchors {
            left: parent.left
            leftMargin: Constants.innerPadding
            right: parent.right
            rightMargin: Constants.innerPadding
            verticalCenter: parent.verticalCenter
        }
        spacing: Constants.innerPadding

        Item {
            id: iconArea
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                id: iconImg
                anchors.centerIn: parent
                source: root.entry.iconName ? Quickshell.iconPath(root.entry.iconName) : ""
                implicitSize: parent.height
                smooth: true
                visible: !!root.entry.iconName
            }

            Text {
                anchors.centerIn: parent
                visible: !root.entry.iconName
                text: (() => {
                    if (root.entry.iconGlyph) return root.entry.iconGlyph
                    const cats = root.entry.categories
                    if (cats)
                        for (const [k, v] of Object.entries(Constants.icons.categoryIcons))
                            if (cats.includes(k)) return v
                    return Constants.icons.desktopIcon
                })()
                color: root.selected ? Constants.nord8 : Constants.nord9
                font.family: Constants.font.family
                font.pointSize: Constants.font.iconSize
                renderType: Text.NativeRendering
                Behavior on color { CAnim {} }
            }
        }

        Column {
            id: contentCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: root.entry.name
                color: root.selected ? Constants.nord6 : Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.normalSize
                renderType: Text.NativeRendering
                Behavior on color { CAnim {} }
            }

            Text {
                visible: !!(root.entry.description)
                text: root.entry.description ?? ""
                color: root.selected ? Constants.nord6 : Constants.nord4
                font.family: Constants.font.family
                font.pointSize: Constants.font.smallSize
                renderType: Text.NativeRendering
                Behavior on color { CAnim {} }
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: {
            root.entry.run()
            if (!root.entry.keepOpen) root.launched()
        }
    }
}
