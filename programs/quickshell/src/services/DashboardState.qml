pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property string tab: "apps"
    property bool visible: false

    function open(t: string) { tab = t; visible = true }
    function close() { visible = false }
    function toggle(t: string) { visible && tab === t ? close() : open(t) }
    function switchTab(t: string) { if (visible) tab = t }
}
