pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common

// Stránka Power v Nexusu: profil výkonu a co se stane při nečinnosti. V menu je jen v prostředí desk (viz PageRegistry).
PageBase {
    id: root

    readonly property var timeouts: GlobalConfig.general.idle.timeouts.values

    readonly property list<MenuItem> profileItems: [
        MenuItem {
            text: "Power saver"
            value: PowerProfile.PowerSaver
        },
        MenuItem {
            text: "Balanced"
            value: PowerProfile.Balanced
        },
        MenuItem {
            text: "Performance"
            value: PowerProfile.Performance
        }
    ]

    function isSleep(action: var): bool {
        return /suspend|hibernate/.test(String(action));
    }

    function matches(entry: var, kind: var): bool {
        return kind === "sleep" ? isSleep(entry.idleAction) : entry.idleAction === kind;
    }

    function minutesFor(kind: var): int {
        const entry = timeouts.find(candidate => matches(candidate, kind));
        return entry && (entry.enabled ?? true) ? Math.round(entry.timeout / 60) : 0;
    }

    // Nula znamená nikdy
    function setMinutes(kind: var, minutes: int): void {
        const list = GlobalConfig.general.idle.timeouts;
        const index = Array.from({ length: list.count }, (_, position) => position).find(position => matches(list.at(position), kind));
        const entry = index === undefined ? list.insert(newTimeout(kind)) : list.at(index);
        entry.enabled = minutes > 0;
        if (minutes > 0)
            entry.timeout = minutes * 60;
        // Výchozí suspendThenHibernate bez swapu na disku nefunguje, logind ho hlásí jako nedostupný
        if (minutes > 0 && kind === "sleep")
            entry.idleAction = ["systemctl", "suspend"];
    }

    function newTimeout(kind: var): var {
        if (kind === "sleep")
            return { timeout: 1800, idleAction: ["systemctl", "suspend"] };
        if (kind === "dpms off")
            return { timeout: 600, idleAction: "dpms off", returnAction: "dpms on" };
        return { timeout: 300, idleAction: kind };
    }

    title: "Power"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Performance"
        }

        SelectRow {
            first: true
            last: true
            label: "Power profile"
            subtext: "Saver is slower and uses less energy, performance is the opposite"
            menuItems: root.profileItems
            active: menuItems.find(item => item.value === PowerProfiles.profile) ?? null
            fallbackText: "Unknown"
            onSelected: item => PowerProfiles.profile = item.value
        }

        SectionHeader {
            text: "When idle"
        }

        StepperRow {
            first: true
            label: "Lock the screen after"
            subtext: "Minutes, 0 means never"
            to: 240
            value: root.minutesFor("lock")
            onMoved: value => root.setMinutes("lock", value)
        }

        StepperRow {
            label: "Turn off displays after"
            subtext: "Minutes, 0 means never"
            to: 240
            value: root.minutesFor("dpms off")
            onMoved: value => root.setMinutes("dpms off", value)
        }

        StepperRow {
            last: true
            label: "Sleep after"
            subtext: "Minutes, 0 means never"
            to: 240
            value: root.minutesFor("sleep")
            onMoved: value => root.setMinutes("sleep", value)
        }

        SectionHeader {
            text: "Options"
        }

        ToggleRow {
            first: true
            text: "Lock before sleep"
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        ToggleRow {
            text: "Stay awake while audio is playing"
            checked: GlobalConfig.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        ToggleRow {
            last: true
            text: "Stay awake on AC power"
            subtext: "A desktop is always on AC, so this turns off everything above"
            checked: GlobalConfig.general.idle.inhibitWhenCharging
            onToggled: GlobalConfig.general.idle.inhibitWhenCharging = checked
        }
    }
}
