pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Klávesnice a myš pro stránku Keyboard & mouse v prostředí desk. Ukládá se do verzovaného desk/input-settings.json,
// který čte i desk/config.lua při startu; změna se hned použije přes hyprctl eval. Caelestia tuhle službu nepoužívá.
Singleton {
    id: root

    property real sensitivity: 0
    property bool acceleration: true
    property bool naturalScroll: false
    property int repeatDelay: 250
    property int repeatRate: 35

    function clamped(value: real, low: real, high: real): real {
        return Math.max(low, Math.min(high, value));
    }

    function set(key: string, value: var): void {
        if (key === "sensitivity")
            sensitivity = Math.round(clamped(value, -1, 1) * 100) / 100;
        else if (key === "repeatDelay")
            repeatDelay = clamped(value, 150, 1000);
        else if (key === "repeatRate")
            repeatRate = clamped(value, 10, 60);
        else
            root[key] = value;
        file.save({ sensitivity, acceleration, naturalScroll, repeatDelay, repeatRate });
        apply();
    }

    function apply(): void {
        HyprWindows.setInput(sensitivity, acceleration, naturalScroll, repeatDelay, repeatRate);
    }

    JsonFile {
        id: file

        path: `${ShellEnv.deskDir}/input-settings.json`
        onValueLoaded: {
            const saved = file.value ?? {};
            root.sensitivity = root.clamped(Number(saved.sensitivity ?? 0), -1, 1);
            root.acceleration = saved.acceleration ?? true;
            root.naturalScroll = saved.naturalScroll ?? false;
            root.repeatDelay = root.clamped(Number(saved.repeatDelay ?? 250), 150, 1000);
            root.repeatRate = root.clamped(Number(saved.repeatRate ?? 35), 10, 60);
        }
    }
}
