import QtQuick
import qs.services
import qs.components
import qs
import Quickshell.Services.Notifications
import QtQuick.Layouts

ListView {
    model: Notifs.popups

    delegate: Notif {
    }

    orientation: ListView.Vertical
    spacing: Constants.innerPadding
    height: contentHeight
    width: 500
}
