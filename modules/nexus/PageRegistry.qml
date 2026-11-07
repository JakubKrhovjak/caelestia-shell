pragma Singleton

import QtQuick
import qs.services
import Caelestia.I18n

QtObject {
    id: root

    readonly property list<var> pages: [
        // Appearance
        {
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance"
        },

        // Connectivity
        // TODO
        // {
        //     label: Tr.tr("Display"),
        //     icon: "monitor",
        //     description: Tr.tr("Output configuration"),
        //     category: "connectivity"
        // },
        {
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity"
        },
        // Jen prostředí desk: v Caelestii je řádek skrytý, pořadí stránek musí sedět s PageCompRegistry
        {
            id: "nightshift",
            label: "Night Shift",
            icon: "bedtime",
            description: "Warmer colours, sunset schedule",
            category: ShellEnv.isDesk ? "connectivity" : "hidden"
        },
        {
            id: "displays",
            label: "Displays",
            icon: "monitor",
            description: "Arrangement, resolution, scale",
            category: ShellEnv.isDesk ? "connectivity" : "hidden"
        },

        // System
        {
            id: "power",
            label: "Power",
            icon: "bolt",
            description: "Performance, sleep, screen off",
            category: ShellEnv.isDesk ? "system" : "hidden"
        },
        {
            id: "input",
            label: "Keyboard & mouse",
            icon: "mouse",
            description: "Pointer speed, scrolling, key repeat",
            category: ShellEnv.isDesk ? "system" : "hidden"
        },
        {
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system"
        },
        {
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: ShellEnv.isDesk ? "hidden" : "system"
        },

        // Shell
        {
            id: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: ShellEnv.isDesk ? "Panel size, dashboard, launcher, sidebar" : Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            id: "language",
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell"
        },

        // About
        {
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about"
        },
    ]
}
