pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Velikost panelu prostředí desk a jeho ikon. Nastavuje ji stránka v Nexusu, Caelestia ji nepoužívá.
// Patří do verzovaného desk/ vedle autostart.json: je to nastavení, ne běhový stav.
Singleton {
    id: root

    readonly property int minPanelHeight: 32
    readonly property int maxPanelHeight: 72
    readonly property int minIconSize: 16
    readonly property int maxIconSize: 48
    readonly property int defaultIconSize: 28
    // Krytí v procentech. Dolní mez musí být nad ignore_alpha pravidla panelu v hyprland.lua, jinak zmizí rozmazání
    readonly property int minPanelOpacity: 25
    readonly property int maxPanelOpacity: 100

    // Pod touhle výškou se v panelu nevejdou dva řádky hodin
    readonly property int twoLineClockHeight: 42

    property int panelHeight: 46
    property int requestedIconSize: defaultIconSize
    property int requestedTrayIconSize: 22
    property int panelOpacity: 50
    // Co může přebírat krytí panelu. Posuvník položku odpojí, tlačítko ji zase spojí.
    component LinkedOpacity: QtObject {
        property bool linked
        property int separate
        readonly property int value: linked ? root.panelOpacity : separate

        function set(percent: real): void {
            separate = root.clamped(percent, root.minPanelOpacity, root.maxPanelOpacity);
            linked = false;
            saveTimer.restart();
        }

        function setLinked(newLinked: bool): void {
            // Po odpojení zůstane položka tam, kde byla, ať neskočí
            separate = value;
            linked = newLinked;
            saveTimer.restart();
        }
    }

    // Titulkové lišty oken kreslí Hyprland
    readonly property LinkedOpacity windowBars: LinkedOpacity {
        linked: true
        separate: 50
        onValueChanged: windowBarTimer.restart()
    }
    // Terminál má zůstat čitelný, proto je ve výchozím stavu neprůhledný a odpojený
    readonly property LinkedOpacity ghostty: LinkedOpacity {
        linked: false
        separate: 100
        onValueChanged: ghosttyTimer.restart()
    }
    // Výška, se kterou počítají okna; po změně je přepočítá panel
    property int fittedPanelHeight: panelHeight

    signal panelResized(oldHeight: int)

    // Ikona se musí vejít do tlačítka i při malém panelu
    readonly property int iconSize: Math.min(requestedIconSize, panelHeight - 10)
    readonly property int smallIconSize: iconSize - 4
    readonly property int trayIconSize: Math.min(requestedTrayIconSize, panelHeight - 10)
    readonly property real iconScale: iconSize / defaultIconSize

    readonly property int groupHeight: panelHeight - 6
    readonly property int taskSize: panelHeight - 6
    readonly property int buttonSize: panelHeight - 8
    readonly property int smallButtonSize: panelHeight - 12

    function clamped(value: real, low: int, high: int): int {
        return Math.round(Math.max(low, Math.min(high, value)));
    }

    function setPanelHeight(value: real): void {
        panelHeight = clamped(value, minPanelHeight, maxPanelHeight);
        saveTimer.restart();
    }

    function setIconSize(value: real): void {
        requestedIconSize = clamped(value, minIconSize, maxIconSize);
        saveTimer.restart();
    }

    function setTrayIconSize(value: real): void {
        requestedTrayIconSize = clamped(value, minIconSize, maxIconSize);
        saveTimer.restart();
    }

    function setPanelOpacity(value: real): void {
        panelOpacity = clamped(value, minPanelOpacity, maxPanelOpacity);
        saveTimer.restart();
    }

    // Tažení posuvníku posílá hodnoty rychle za sebou, Hyprlandu stačí ta poslední
    Timer {
        id: windowBarTimer

        interval: 50
        onTriggered: Quickshell.execDetached(["hyprctl", "eval", `window_bar_opacity(${root.windowBars.value})`])
    }

    // Ghostty kvůli změně znovu načítá celou konfiguraci, proto delší prodleva
    Timer {
        id: ghosttyTimer

        interval: 300
        onTriggered: Quickshell.execDetached([`${ShellEnv.deskDir}/ghostty-opacity.sh`, `${root.ghostty.value}`])
    }

    // Posuvník mění hodnotu plynule, na disk stačí konečný stav
    Timer {
        id: saveTimer

        interval: 300
        onTriggered: {
            store.save({ panelHeight: root.panelHeight, iconSize: root.requestedIconSize, trayIconSize: root.requestedTrayIconSize, panelOpacity: root.panelOpacity, windowBarsLinked: root.windowBars.linked, windowBarOpacity: root.windowBars.value, ghosttyLinked: root.ghostty.linked, ghosttyOpacity: root.ghostty.value });
            if (root.panelHeight !== root.fittedPanelHeight) {
                const oldHeight = root.fittedPanelHeight;
                root.fittedPanelHeight = root.panelHeight;
                root.panelResized(oldHeight);
            }
        }
    }

    JsonFile {
        id: store

        path: `${ShellEnv.deskDir}/panel-settings.json`
        // Panel má naběhnout rovnou ve své výšce: skok z výchozí hodnoty by Hyprland odnesl na oknech
        blockLoading: true
        // Soubor zapisuje jen tahle služba; sledování by při tažení posuvníku vracelo starší hodnotu
        watchChanges: false
        onValueLoaded: {
            root.panelHeight = root.clamped(value?.panelHeight ?? root.panelHeight, root.minPanelHeight, root.maxPanelHeight);
            root.fittedPanelHeight = root.panelHeight;
            root.requestedIconSize = root.clamped(value?.iconSize ?? root.requestedIconSize, root.minIconSize, root.maxIconSize);
            // Starší soubor velikost pro tray nemá: dřív byla o 6 px menší než ostatní ikony
            root.requestedTrayIconSize = root.clamped(value?.trayIconSize ?? root.requestedIconSize - 6, root.minIconSize, root.maxIconSize);
            root.panelOpacity = root.clamped(value?.panelOpacity ?? root.panelOpacity, root.minPanelOpacity, root.maxPanelOpacity);
            root.windowBars.separate = root.clamped(value?.windowBarOpacity ?? root.panelOpacity, root.minPanelOpacity, root.maxPanelOpacity);
            root.windowBars.linked = value?.windowBarsLinked ?? true;
            root.ghostty.separate = root.clamped(value?.ghosttyOpacity ?? root.ghostty.separate, root.minPanelOpacity, root.maxPanelOpacity);
            root.ghostty.linked = value?.ghosttyLinked ?? false;
        }
    }
}
