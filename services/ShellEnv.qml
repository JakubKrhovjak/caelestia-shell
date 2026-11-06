pragma Singleton

import QtQuick
import Quickshell

// Rozdíly mezi prostředími, která sdílejí tento kód: Caelestia a desk.
Singleton {
    readonly property bool isDesk: Quickshell.shellDir.endsWith("/desk")
    readonly property string deskDir: `${Quickshell.env("HOME")}/.config/desk`

    // Stejná hodnota je v desk/config.lua, Lua a QML nemají společné úložiště
    readonly property string minimizedWorkspace: "special:minimized"
}
