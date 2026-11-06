import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Loader {
            Layout.fillWidth: true
            Layout.bottomMargin: active ? Tokens.spacing.medium : 0
            active: ShellEnv.isDesk
            sourceComponent: DeskPanelSection {}
        }

        NavRow {
            first: true
            icon: "dashboard"
            text: Tr.tr("Dashboard")
            subtext: Config.dashboard.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(1)
        }

        // Lišta Caelestie v desk neběží, panel má vlastní nastavení výše
        NavRow {
            visible: !ShellEnv.isDesk
            icon: "dock_to_bottom"
            text: Tr.tr("Taskbar")
            subtext: Config.bar.persistent ? Tr.tr("Always visible") : Config.bar.showOnHover ? Tr.tr("Reveal on hover") : Tr.tr("Reveal on drag")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            icon: "apps"
            text: Tr.tr("Launcher")
            subtext: Config.launcher.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            icon: "dock_to_right"
            text: Tr.tr("Sidebar")
            subtext: Config.sidebar.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(4)
        }

        NavRow {
            last: true
            icon: "construction"
            text: Tr.tr("Utilities")
            subtext: Config.utilities.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(5)
        }
    }
}
