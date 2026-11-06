//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "modules/windowswitcher"
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components.filedialog
import qs.services

ShellRoot {
    id: root

    settings.watchFiles: false

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    GSFLoader {}
    ServiceLoader {}

    Background {}
    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }

    // Vlastní dvoupanelový dialog souborů: qs -c caelestia ipc call files open
    FileDialog {
        id: filePicker

        title: "Files"
        onAccepted: path => Quickshell.execDetached(["xdg-open", path])
    }

    IpcHandler {
        target: "files"

        function open(): void {
            filePicker.open();
        }

        function close(): void {
            filePicker.close();
        }
    }

    // Karusel oken na Alt + Tab (zkratky v ~/.config/caelestia/hypr-user.lua)
    WindowSwitcher {}

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
