pragma Singleton

import QtQuick
import Quickshell

// Rozdíly mezi prostředími, která sdílejí tento kód: Caelestia a desk.
Singleton {
    readonly property bool isDesk: Quickshell.shellDir.endsWith("/desk")
    readonly property string deskDir: `${Quickshell.env("HOME")}/.config/desk`
    // Stav panelu mimo git; stejná cesta je v desk/config.lua a desk/nightshift.sh
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/desk`

    // Stejná hodnota je v desk/config.lua, Lua a QML nemají společné úložiště
    readonly property string minimizedWorkspace: "special:minimized"

    // Přes celou obrazovku běží třeba hra, panely ji nemají překrývat
    function hasFullscreen(workspace: var): bool {
        return workspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }
}
