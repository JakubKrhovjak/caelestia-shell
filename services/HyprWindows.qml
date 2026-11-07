pragma Singleton

import QtQuick
import Quickshell

// Jediné místo, které z QML skládá příkazy pro Hyprland (hyprctl eval). Funkce na druhé straně jsou v desk/*.lua;
// ty existují jen v prostředí desk, Caelestia odsud používá jen obecné příkazy (focus, raise).
Singleton {
    // Hyprland hlásí adresu s předponou 0x, Quickshell bez ní
    function address(value: string): string {
        return `0x${value.replace(/^0x/, "")}`;
    }

    function selector(value: string): string {
        return `"address:${address(value)}"`;
    }

    // Víc kroků musí jít v jednom příkazu: samostatné procesy se můžou předběhnout
    function run(lines: var): void {
        Quickshell.execDetached(["hyprctl", "eval", lines.join("; ")]);
    }

    function focus(value: string): string {
        return `hl.dispatch(hl.dsp.focus({ window = ${selector(value)} }))`;
    }

    // Fokus a zvednutí nad ostatní plovoucí okna; v Caelestii, kde restore_window není
    function focusAndRaise(value: string): void {
        run([focus(value), "hl.dispatch(hl.dsp.window.bring_to_top())"]);
    }

    function raise(value: string): void {
        run([`restore_window("${address(value)}")`]);
    }

    // Minimalizované okno na danou plochu; fokus na skrytou plochu by ji celou otevřel (desk/minimize.lua)
    function restoreTo(value: string, workspace: int): string {
        return `restore_window("${address(value)}", ${workspace})`;
    }

    function restoreMinimized(value: string, workspace: int): void {
        run([`restore_minimized("${address(value)}", ${workspace})`]);
    }

    function show(toplevel: var): void {
        if (ShellEnv.isMinimized(toplevel))
            restoreMinimized(toplevel.address, toplevel.monitor?.activeWorkspace?.id ?? Hypr.focusedWorkspace?.id ?? 1);
        else
            raise(toplevel.address);
    }

    // Okno z Alt + Tab: minimalizované vrátí restore_window, rozložené pod plovoucím se přepne na plovoucí se stejnou
    // geometrií, jinak by nešlo zvednout. win je objekt z hyprctl clients -j.
    function activate(win: var, minimizedWorkspace: string, floatOver: bool): void {
        const target = selector(win.address);
        const restore = minimizedWorkspace !== "" && win.workspace.name === minimizedWorkspace
            ? [restoreTo(win.address, Hypr.focusedMonitor?.activeWorkspace?.id ?? 1)] : [];
        const float = floatOver ? [
            `hl.dispatch(hl.dsp.window.float({ action = "on", window = ${target} }))`,
            `hl.dispatch(hl.dsp.window.resize({ x = ${win.size[0]}, y = ${win.size[1]}, relative = false, window = ${target} }))`,
            `hl.dispatch(hl.dsp.window.move({ x = ${win.at[0]}, y = ${win.at[1]}, relative = false, window = ${target} }))`,
        ] : [];
        run([...restore, focus(win.address), ...float, "hl.dispatch(hl.dsp.window.bring_to_top())"]);
    }

    // Názvy tříd určují aplikace a jdou do Lua jako kód, proto jen znaky, které se v nich běžně vyskytují
    function setTrayClasses(classes: var): void {
        const names = classes.filter(name => /^[\w.-]+$/.test(name)).map(name => `"${name}"`);
        run([`set_tray_classes({ ${names.join(", ")} })`]);
    }

    function fitWindowsToPanel(oldHeight: int): void {
        run([`fit_windows_to_panel(${oldHeight})`]);
    }

    function panelMoved(monitor: string, panelHeight: int): void {
        run([`panel_moved("${monitor}", ${panelHeight})`]);
    }

    // Krytí v procentech ze stránky Panels (desk/bars.lua a desk/window-behavior.lua)
    function setWindowBarOpacity(percent: int): void {
        run([`window_bar_opacity(${percent})`]);
    }

    function setShellWindowOpacity(percent: int): void {
        run([`window_opacity(${percent})`]);
    }

    // Klávesnice a myš ze stránky Keyboard & mouse; hodnoty jsou už sevřené v DeskInput
    function setInput(sensitivity: real, acceleration: bool, naturalScroll: bool, repeatDelay: int, repeatRate: int): void {
        run([`hl.config({ input = { sensitivity = ${sensitivity}, accel_profile = "${acceleration ? "adaptive" : "flat"}", natural_scroll = ${naturalScroll}, repeat_delay = ${repeatDelay}, repeat_rate = ${repeatRate} } })`]);
    }

    // Stejně jako křížek v liště okna: aplikaci s ikonou v trayi jen schová
    function closeFromBar(value: string): void {
        run([focus(value), "close_active()"]);
    }

    function close(value: string): void {
        run([`hl.dispatch(hl.dsp.window.close({ window = ${selector(value)} }))`]);
    }

    function togglePin(value: string): void {
        run([`hl.dispatch(hl.dsp.window.pin({ action = "toggle", window = ${selector(value)} }))`]);
    }

    function minimize(value: string): void {
        run([focus(value), "minimize_active()"]);
    }

    function toggleMaximize(value: string): void {
        run([focus(value), "toggle_maximize()"]);
    }

    function focusMonitor(name: string): void {
        run([`hl.dispatch(hl.dsp.focus({ monitor = "${name}" }))`]);
    }
}
