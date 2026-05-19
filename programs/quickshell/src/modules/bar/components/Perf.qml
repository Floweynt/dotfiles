import QtQuick.Layouts
import QtQuick
import qs
import qs.components
import qs.floweyshell 1.0
import Quickshell.Services.UPower

BarContainer {
    id: root

    readonly property var _sm: SysmonProvider

    width: contents.implicitWidth + 2 * Constants.innerPadding
    color: Constants.nord3

    RowLayout {
        id: contents
        anchors.fill: parent
        anchors.margins: Constants.innerPadding

        Item {
            implicitHeight: parent.height
            implicitWidth: implicitHeight

            IconText {
                anchors.centerIn: parent
                text: ""
            }
        }

        BarText {
            property int perc: Math.round(root._sm.cpuTotal)
            renderType: Text.QtRendering
            readonly property var colorMap: [[90, Constants.nord11], [75, Constants.nord12], [50, Constants.nord13], [-1, Constants.nord14],]
            text: perc.toString().padStart(2, "0")
            color: colorMap.find(x => perc > x[0])[1]
        }

        Item {
            implicitHeight: parent.height
            implicitWidth: implicitHeight

            IconText {
                anchors.centerIn: parent
                text: "󰘚"
            }
        }

        BarText {
            property int perc: root._sm.memTotal > 0 ? Math.round(root._sm.memUsed / root._sm.memTotal * 100) : 0
            renderType: Text.QtRendering
            readonly property var colorMap: [[90, Constants.nord11], [75, Constants.nord12], [50, Constants.nord13], [-1, Constants.nord14],]
            text: perc.toString().padStart(2, "0")
            color: colorMap.find(x => perc > x[0])[1]
        }

        Item {
            implicitHeight: parent.height
            implicitWidth: implicitHeight

            IconText {
                property int perc: Math.round(UPower.displayDevice.percentage * 100)
                readonly property var iconMap: [[95, "󰁹"], [85, "󰂂"], [75, "󰂁"], [65, "󰂀"], [55, "󰁿"], [45, "󰁾"], [35, "󰁽"], [25, "󰁼"], [15, "󰁻"], [5, "󰁺"], [-1, "󰂎"]]
                anchors.centerIn: parent
                text: iconMap.find(x => perc > x[0])[1]
            }
        }

        BarText {
            property int perc: Math.round(UPower.displayDevice.percentage * 100)
            readonly property var colorMap: [[50, Constants.nord14], [30, Constants.nord13], [20, Constants.nord12], [-1, Constants.nord11],]
            text: perc.toString().padStart(2, "0")
            color: colorMap.find(x => perc > x[0])[1]
        }

        BarText {
            function formatSeconds(s: int, fallback: string): string {
                const day = Math.floor(s / 86400);
                const hr = Math.floor(s / 3600) % 60;
                const min = Math.floor(s / 60) % 60;

                let comps = [];
                if (day > 0)
                    comps.push(`${day} days`);
                if (hr > 0)
                    comps.push(`${hr}h`);
                if (min > 0)
                    comps.push(`${min}m`);

                return comps.join(" ") || fallback;
            }
            text: "(%1) %2".arg(UPower.onBattery ? "-" : "+").arg(UPower.onBattery ? formatSeconds(UPower.displayDevice.timeToEmpty, "...") : formatSeconds(UPower.displayDevice.timeToFull, "F"))
        }
    }
}
