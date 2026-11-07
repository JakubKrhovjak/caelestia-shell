pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Klávesnice a myš pro stránku Keyboard & mouse v prostředí desk. Ukládá se do desk/input-settings.json, který čte
// i desk/config.lua při startu (tam jsou stejné meze, viz load_input); změna se hned použije přes HyprWindows.
// Caelestia tuhle službu nepoužívá.
Singleton {
    id: root

    // Jediné místo s mezemi a výchozími hodnotami v QML; stránka bere from a to odsud
    readonly property var limits: ({
            sensitivity: { from: -1, to: 1, initial: 0 },
            repeatDelay: { from: 150, to: 1000, initial: 250 },
            repeatRate: { from: 10, to: 60, initial: 35 }
        })

    property real sensitivity: limits.sensitivity.initial
    property bool acceleration: true
    property bool naturalScroll: false
    property int repeatDelay: limits.repeatDelay.initial
    property int repeatRate: limits.repeatRate.initial

    function clamped(key: string, value: var): real {
        const limit = limits[key];
        const number = Number(value);
        return isNaN(number) ? limit.initial : Math.max(limit.from, Math.min(limit.to, number));
    }

    function set(key: string, value: var): void {
        if (key === "sensitivity")
            sensitivity = Math.round(clamped(key, value) * 100) / 100;
        else if (key in limits)
            root[key] = Math.round(clamped(key, value));
        else
            root[key] = value;
        applyTimer.restart();
        saveTimer.restart();
    }

    // Tažení posuvníku posílá hodnoty rychle za sebou: Hyprlandu stačí ta poslední, na disk konečný stav
    Timer {
        id: applyTimer

        interval: 50
        onTriggered: HyprWindows.setInput(root.sensitivity, root.acceleration, root.naturalScroll, root.repeatDelay, root.repeatRate)
    }

    Timer {
        id: saveTimer

        interval: 300
        onTriggered: file.save({ sensitivity: root.sensitivity, acceleration: root.acceleration, naturalScroll: root.naturalScroll, repeatDelay: root.repeatDelay, repeatRate: root.repeatRate })
    }

    JsonFile {
        id: file

        path: `${ShellEnv.deskDir}/input-settings.json`
        onValueLoaded: {
            const saved = file.value ?? {};
            root.sensitivity = root.clamped("sensitivity", saved.sensitivity);
            root.acceleration = saved.acceleration ?? true;
            root.naturalScroll = saved.naturalScroll ?? false;
            root.repeatDelay = root.clamped("repeatDelay", saved.repeatDelay);
            root.repeatRate = root.clamped("repeatRate", saved.repeatRate);
        }
    }
}
