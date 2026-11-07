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
    readonly property string minimizedWorkspace: Quickshell.env("DESK_MINIMIZED_WORKSPACE") || "special:minimized"
    readonly property string shellClass: Quickshell.env("DESK_SHELL_CLASS") || "org.quickshell"
    readonly property string toolboxClass: Quickshell.env("DESK_TOOLBOX_CLASS") || "jetbrains-toolbox"

    // Plochy oken Nastavení a Files: v desk neprůhledné, průhlednost dává Hyprland vlastností okna (desk/window-behavior.lua);
    // v Caelestii průhledná paleta jako dřív
    readonly property var surfacePalette: isDesk ? Colours.palette : Colours.tPalette

    function isMinimized(toplevel: var): bool {
        return toplevel?.workspace?.name === minimizedWorkspace;
    }

    // Přes celou obrazovku běží třeba hra, panely ji nemají překrývat
    function hasFullscreen(workspace: var): bool {
        return workspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }
}
