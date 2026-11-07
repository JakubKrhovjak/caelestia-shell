pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

// Stránka Keyboard & mouse v Nexusu: rychlost a zrychlení kurzoru, směr posouvání, opakování kláves.
// V menu je jen v prostředí desk (viz PageRegistry), hodnoty drží služba DeskInput.
PageBase {
    id: root

    title: "Keyboard & mouse"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Mouse"
        }

        SliderRow {
            first: true
            icon: "speed"
            label: "Pointer speed"
            valueLabel: DeskInput.sensitivity > 0 ? `+${DeskInput.sensitivity}` : `${DeskInput.sensitivity}`
            value: (DeskInput.sensitivity + 1) / 2
            onMoved: value => DeskInput.set("sensitivity", value * 2 - 1)
        }

        ToggleRow {
            text: "Mouse acceleration"
            subtext: "Faster movement moves the pointer further"
            checked: DeskInput.acceleration
            onToggled: DeskInput.set("acceleration", checked)
        }

        ToggleRow {
            last: true
            text: "Natural scrolling"
            subtext: "Content follows the wheel, as on a Mac"
            checked: DeskInput.naturalScroll
            onToggled: DeskInput.set("naturalScroll", checked)
        }

        SectionHeader {
            text: "Keyboard"
        }

        StepperRow {
            first: true
            label: "Repeat delay"
            subtext: "Milliseconds before a held key starts repeating"
            from: DeskInput.limits.repeatDelay.from
            to: DeskInput.limits.repeatDelay.to
            stepSize: 50
            value: DeskInput.repeatDelay
            onMoved: value => DeskInput.set("repeatDelay", value)
        }

        StepperRow {
            last: true
            label: "Repeat rate"
            subtext: "Characters per second while a key is held"
            from: DeskInput.limits.repeatRate.from
            to: DeskInput.limits.repeatRate.to
            value: DeskInput.repeatRate
            onMoved: value => DeskInput.set("repeatRate", value)
        }
    }
}
