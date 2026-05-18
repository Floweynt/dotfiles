//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=2500

import Quickshell
import qs.modules
import qs.modules.dashboard
import qs.modules.polkit

ShellRoot {
    Shell {}
    Dashboard {}
    PolkitAuth {}
}

