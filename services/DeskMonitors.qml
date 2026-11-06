pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Rozložení monitorů pro stránku Displays v prostředí desk. Návrh se upravuje v paměti, použití ho zapíše
// do desk/monitor-settings.lua a bez potvrzení se samo vrátí, aby špatný režim nenechal černou obrazovku.
Singleton {
    id: root

    readonly property int confirmSeconds: 15

    property var outputs: []
    property string selectedName
    property string mainName: ShellEnv.mainMonitor
    property bool dirty: false
    property bool pending: false
    property int secondsLeft: 0

    property string previousText
    property bool restartOnKeep: false

    readonly property var selected: outputs.find(output => output.name === selectedName) ?? null

    function load(): void {
        if (!reader.running)
            reader.running = true;
    }

    function parse(text: string): void {
        outputs = JSON.parse(text).map(monitor => ({
                    name: monitor.name,
                    description: monitor.description,
                    modes: monitor.availableModes.map(mode => mode.replace(/Hz$/, "")),
                    mode: monitor.disabled ? monitor.availableModes[0].replace(/Hz$/, "") : `${monitor.width}x${monitor.height}@${monitor.refreshRate.toFixed(2)}`,
                    x: monitor.x,
                    y: monitor.y,
                    scale: monitor.scale,
                    transform: monitor.transform,
                    disabled: monitor.disabled
                }));
        dirty = false;
        if (!selected)
            selectedName = outputs.find(output => output.name === mainName)?.name ?? outputs[0]?.name ?? "";
    }

    // Do parse nepatří: ten běží i po použití a během odpočtu by přepsal volbu
    function reset(): void {
        mainName = ShellEnv.mainMonitor;
        load();
    }

    // Velikost na ploše: po měřítku a otočení
    function logicalSize(output: var): var {
        const [width, height] = output.mode.split("@")[0].split("x").map(Number);
        const rotated = output.transform % 2 === 1;
        return {
            w: Math.round((rotated ? height : width) / output.scale),
            h: Math.round((rotated ? width : height) / output.scale)
        };
    }

    function update(name: string, patch: var): void {
        outputs = outputs.map(output => output.name === name ? Object.assign({}, output, patch) : output);
        dirty = true;
    }

    // Monitory na sebe musí navazovat: nejbližší poloha u hrany některého z ostatních
    function snapped(output: var, x: real, y: real): var {
        const size = logicalSize(output);
        const others = outputs.filter(other => other.name !== output.name && !other.disabled);
        const candidates = others.flatMap(other => {
            const otherSize = logicalSize(other);
            const alongY = Math.max(other.y - size.h + 1, Math.min(other.y + otherSize.h - 1, Math.abs(y - other.y) < 100 ? other.y : y));
            const alongX = Math.max(other.x - size.w + 1, Math.min(other.x + otherSize.w - 1, Math.abs(x - other.x) < 100 ? other.x : x));
            return [
                { x: other.x - size.w, y: alongY },
                { x: other.x + otherSize.w, y: alongY },
                { x: alongX, y: other.y - size.h },
                { x: alongX, y: other.y + otherSize.h }
            ];
        });
        const distance = candidate => Math.hypot(candidate.x - x, candidate.y - y);
        return candidates.reduce((best, candidate) => !best || distance(candidate) < distance(best) ? candidate : best, null) ?? { x: 0, y: 0 };
    }

    // Rozložení začíná v počátku souřadnic
    function normalize(): void {
        const shown = outputs.filter(output => !output.disabled);
        const minX = Math.min(...shown.map(output => output.x));
        const minY = Math.min(...shown.map(output => output.y));
        outputs = outputs.map(output => Object.assign({}, output, { x: Math.round(output.x - minX), y: Math.round(output.y - minY) }));
    }

    function moveTo(name: string, x: real, y: real): void {
        const output = outputs.find(candidate => candidate.name === name);
        update(name, snapped(output, x, y));
        normalize();
    }

    // Po změně velikosti by monitor mohl překrývat souseda nebo od něj odskočit
    function reshape(name: string, patch: var): void {
        update(name, patch);
        const output = outputs.find(candidate => candidate.name === name);
        if (!output.disabled)
            moveTo(name, output.x, output.y);
    }

    function setDisabled(name: string, disabled: bool): void {
        if (name !== mainName)
            reshape(name, { disabled });
    }

    function setMain(name: string): void {
        if (!outputs.find(output => output.name === name)?.disabled) {
            mainName = name;
            dirty = true;
        }
    }

    function serialized(): string {
        const safe = outputs.filter(output => /^[\w.-]+$/.test(output.name) && /^\d+x\d+@[\d.]+$/.test(output.mode) && [output.x, output.y, Number(output.scale)].every(Number.isFinite));
        // Odpojený monitor v seznamu z Hyprlandu není, jeho nastavení se nesmí ztratit
        const known = outputs.map(output => output.name);
        const absent = settings.text().split("\n").filter(line => {
            const match = line.match(/\{ name = "([\w.-]+)"/);
            return match && !known.includes(match[1]);
        });
        const absentNames = absent.filter(line => line.includes("disabled = false")).map(line => line.match(/\{ name = "([\w.-]+)"/)[1]);
        const lines = safe.map(output => `        { name = "${output.name}", mode = "${output.mode}", x = ${Math.round(output.x)}, y = ${Math.round(output.y)}, scale = ${Number(output.scale)}, transform = ${Math.round(output.transform)}, disabled = ${output.disabled ? "true" : "false"} },`);
        const side = safe.find(output => output.name !== mainName && !output.disabled)?.name ?? absentNames.find(name => name !== mainName) ?? mainName;
        return ["-- Rozložení monitorů. Soubor generuje stránka Displays v Nastavení, ruční úpravy přepíše.", "return {", `    main = "${mainName}",`, `    side = "${side}",`, "    outputs = {", ...lines, ...absent, "    },", "}", ""].join("\n");
    }

    // Zálohu na disku obnoví start.sh, kdyby přihlášení skončilo dřív než odpočet
    function apply(): void {
        // Bez načtené zálohy by návrat zapsal prázdný soubor
        if (!settings.text())
            return;
        previousText = settings.text();
        restartOnKeep = mainName !== ShellEnv.mainMonitor;
        secondsLeft = confirmSeconds;
        pending = true;
        backup.setText(previousText);
    }

    function dropBackup(): void {
        Quickshell.execDetached(["rm", "-f", backup.path]);
    }

    // Panel běží na monitoru podle prostředí shellu, nový hlavní monitor potřebuje jeho restart a okna přepočet
    function keep(): void {
        pending = false;
        dropBackup();
        if (restartOnKeep) {
            Quickshell.execDetached(["hyprctl", "eval", `panel_moved("${ShellEnv.mainMonitor}", ${DeskPanelSettings.panelHeight})`]);
            Quickshell.execDetached([`${ShellEnv.deskDir}/restart-shell.sh`]);
        }
    }

    function revert(): void {
        pending = false;
        mainName = ShellEnv.mainMonitor;
        settings.setText(previousText);
        dropBackup();
    }

    Process {
        id: reader

        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    FileView {
        id: backup

        path: `${ShellEnv.stateDir}/monitor-settings.previous.lua`
        preload: false
        printErrors: false
        onSaved: settings.setText(root.serialized())
    }

    FileView {
        id: settings

        path: `${ShellEnv.deskDir}/monitor-settings.lua`
        printErrors: false
        onSaved: {
            Quickshell.execDetached(["hyprctl", "reload"]);
            refresh.restart();
        }
    }

    // Skutečný stav po aplikaci nového rozložení
    Timer {
        id: refresh

        interval: 1500
        onTriggered: root.load()
    }

    Timer {
        running: root.pending
        repeat: true
        interval: 1000
        onTriggered: {
            root.secondsLeft--;
            if (root.secondsLeft <= 0)
                root.revert();
        }
    }
}
