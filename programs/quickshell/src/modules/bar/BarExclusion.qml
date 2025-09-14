import qs.components
import qs

BasicWindow {
    required property var bar;
    name: "bar-border-exclusion"
    exclusiveZone: Constants.outerPadding + bar.height
    implicitWidth: 1
    implicitHeight: 1
}
