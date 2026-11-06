pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    // Nastavení má vždycky jen jedno okno: další otevření ho jen zafokusuje
    property var current: null

    readonly property string titleFormat: Tr.tr("Nexus — %1")

    function create(parent: Item, props: var): void {
        if (current) {
            focusCurrent();
            current.showPage(props?.startPage ?? -1);
        } else
            current = nexusComp.createObject(parent ?? dummy, props);
    }

    // Podle začátku titulku: celý se mění se stránkou a Hyprland ho hlásí se zpožděním
    function isSettingsWindow(toplevel: var): bool {
        return toplevel?.wayland?.appId === "org.quickshell" && (toplevel?.title ?? "").startsWith(titleFormat.arg(""));
    }

    // Otevře stránku podle id z PageRegistry
    function openPage(id: string): void {
        create(null, { startPage: PageRegistry.pages.findIndex(page => page.id === id) });
    }

    function focusCurrent(): void {
        const toplevel = Hypr.toplevels.values.find(t => isSettingsWindow(t));
        if (!toplevel)
            return;

        const address = `0x${toplevel.address.replace(/^0x/, "")}`;
        // Minimalizované okno existuje jen v desk, vrací ho restore_window z desk/minimize.lua
        const lines = ShellEnv.isMinimized(toplevel)
            ? [`restore_window("${address}", ${Hypr.focusedWorkspace?.id ?? 1})`]
            : [`hl.dispatch(hl.dsp.focus({ window = "address:${address}" }))`, "hl.dispatch(hl.dsp.window.bring_to_top())"];
        Quickshell.execDetached(["hyprctl", "eval", lines.join("; ")]);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            // Stránka, na které se okno otevře; -1 nechá výchozí
            property int startPage: -1

            function showPage(page: int): void {
                if (page >= 0)
                    nexus.nState.currentPageIdx = page;
            }

            Component.onCompleted: showPage(startPage)

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            Component.onDestruction: root.current = null

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: root.titleFormat.arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Nexus {
                id: nexus

                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
