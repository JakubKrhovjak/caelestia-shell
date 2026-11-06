pragma Singleton

import QtQuick
import Quickshell

// Rozdíly mezi prostředími, která sdílejí tento kód: Caelestia a desk.
Singleton {
    readonly property bool isDesk: Quickshell.shellDir.endsWith("/desk")
    // Hodnoty posílá desk/hyprland.lua přes hl.env; výchozí platí pro běh mimo desk a pro shell spuštěný ještě před novým přihlášením
    readonly property string deskDir: Quickshell.env("DESK_DIR") || `${Quickshell.env("HOME")}/.config/desk`
    readonly property string stateDir: Quickshell.env("DESK_STATE_DIR") || `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/desk`
    readonly property string mainMonitor: Quickshell.env("DESK_MAIN_MONITOR") ?? ""
    readonly property int edgeGap: Number(Quickshell.env("DESK_EDGE_GAP") || 5)
    readonly property int windowRounding: Number(Quickshell.env("DESK_WINDOW_ROUNDING") || 15)
    readonly property string minimizedWorkspace: Quickshell.env("DESK_MINIMIZED_WORKSPACE") || "special:minimized"

    function isMinimized(toplevel: var): bool {
        return toplevel?.workspace?.name === minimizedWorkspace;
    }

    // Přes celou obrazovku běží třeba hra, panely ji nemají překrývat
    function hasFullscreen(workspace: var): bool {
        return workspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }
}
