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

    // Pod touhle výškou se v panelu nevejdou dva řádky hodin
    readonly property int twoLineClockHeight: 42

    property int panelHeight: 46
    property int requestedIconSize: defaultIconSize
    // Výška, se kterou počítají okna; po změně je přepočítá panel
    property int fittedPanelHeight: panelHeight

    signal panelResized(oldHeight: int)

    // Ikona se musí vejít do tlačítka i při malém panelu
    readonly property int iconSize: Math.min(requestedIconSize, panelHeight - 10)
    readonly property int smallIconSize: iconSize - 4
    readonly property int trayIconSize: iconSize - 6
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

    // Posuvník mění hodnotu plynule, na disk stačí konečný stav
    Timer {
        id: saveTimer

        interval: 300
        onTriggered: {
            store.save({ panelHeight: root.panelHeight, iconSize: root.requestedIconSize });
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
        }
    }
}
