pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Stránka Night Shift v Nexusu; v menu je jen v prostředí desk (viz PageRegistry).
PageBase {
    id: root

    title: "Night Shift"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            last: true
            text: "Enabled"
            subtext: "Warmer screen colours"
            checked: NightShiftState.active
            onToggled: NightShiftState.setActive(checked)
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.medium
            first: true
            last: true
            icon: "thermostat"
            label: "Colour temperature"
            valueLabel: `${NightShiftState.temperature} K`
            value: (NightShiftState.temperature - NightShiftState.warmest) / (NightShiftState.coolest - NightShiftState.warmest)
            onMoved: value => NightShiftState.setTemperature(NightShiftState.warmest + value * (NightShiftState.coolest - NightShiftState.warmest))
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.medium
            first: true
            last: !NightShiftState.scheduleEnabled
            text: "Turn on automatically"
            checked: NightShiftState.scheduleEnabled
            onToggled: NightShiftState.setScheduleEnabled(checked)
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: NightShiftState.scheduleEnabled
            last: true
            implicitHeight: schedule.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: schedule

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledRadioButton {
                    text: "Sunset to sunrise"
                    font: Tokens.font.body.small
                    checked: NightShiftState.scheduleMode === "sun"
                    onClicked: NightShiftState.setScheduleMode("sun")
                }

                StyledText {
                    Layout.leftMargin: 28
                    text: NightShiftState.sunKnown ? `${NightShiftState.timezone}: sunset ${NightShiftState.formatMinutes(NightShiftState.sunset)}, sunrise ${NightShiftState.formatMinutes(NightShiftState.sunrise)}` : `Not available for time zone ${NightShiftState.timezone || "unknown"}, using custom hours`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledRadioButton {
                    text: "Custom hours"
                    font: Tokens.font.body.small
                    checked: NightShiftState.scheduleMode === "custom"
                    onClicked: NightShiftState.setScheduleMode("custom")
                }

                RowLayout {
                    Layout.leftMargin: 28
                    spacing: Tokens.spacing.medium
                    visible: NightShiftState.scheduleMode === "custom"

                    StyledText {
                        text: "From"
                        font: Tokens.font.body.small
                    }

                    TimeField {
                        value: NightShiftState.scheduleFrom
                        onCommitted: time => NightShiftState.setScheduleTime(time, NightShiftState.scheduleTo)
                    }

                    StyledText {
                        text: "To"
                        font: Tokens.font.body.small
                    }

                    TimeField {
                        value: NightShiftState.scheduleTo
                        onCommitted: time => NightShiftState.setScheduleTime(NightShiftState.scheduleFrom, time)
                    }
                }
            }
        }
    }

    // Pole pro čas ve tvaru 21:00; neplatný zápis se vrátí na poslední platnou hodnotu
    component TimeField: StyledRect {
        id: field

        property string value

        signal committed(time: string)

        implicitWidth: 76
        implicitHeight: 34
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh

        TextInput {
            anchors.fill: parent
            anchors.margins: 6
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            text: field.value
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.small
            selectByMouse: true
            onEditingFinished: {
                if (NightShiftState.isValidTime(text))
                    field.committed(text);
                else
                    text = field.value;
            }
        }
    }
}
