import Quickshell
import Quickshell.Wayland
import qs;

PanelWindow {
    required property string name

    WlrLayershell.namespace: `${Constants.name}-${name}`
    color: "transparent"
}
