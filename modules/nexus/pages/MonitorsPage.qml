pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Stránka Displays v Nexusu; v menu je jen v prostředí desk (viz PageRegistry). Rozložení tažením jako v Plasmě.
PageBase {
    id: root

    readonly property var output: DeskMonitors.selected
    readonly property var resolutions: [...new Set((output?.modes ?? []).map(mode => mode.split("@")[0]))]
    readonly property string resolution: output?.mode.split("@")[0] ?? ""
    readonly property var rates: (output?.modes ?? []).filter(mode => mode.split("@")[0] === resolution)

    readonly property list<MenuItem> scaleItems: [
        MenuItem { text: "100 %"; value: 1 },
        MenuItem { text: "125 %"; value: 1.25 },
        MenuItem { text: "150 %"; value: 1.5 },
        MenuItem { text: "175 %"; value: 1.75 },
        MenuItem { text: "200 %"; value: 2 }
    ]

    readonly property list<MenuItem> rotationItems: [
        MenuItem { text: "None"; value: 0 },
        MenuItem { text: "90°"; value: 1 },
        MenuItem { text: "180°"; value: 2 },
        MenuItem { text: "270°"; value: 3 }
    ]

    title: "Displays"

    Component.onCompleted: DeskMonitors.load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Variants {
            id: resolutionVariants

            model: root.resolutions

            MenuItem {
                required property string modelData

                text: modelData
            }
        }

        Variants {
            id: rateVariants

            model: root.rates

            MenuItem {
                required property string modelData

                text: `${Number(modelData.split("@")[1]).toFixed(2)} Hz`
                value: modelData
            }
        }

        ConnectedRect {
            id: arrangement

            readonly property var shown: DeskMonitors.outputs.filter(output => !output.disabled).map(output => Object.assign({}, output, DeskMonitors.logicalSize(output)))
            readonly property real minX: Math.min(...shown.map(output => output.x))
            readonly property real minY: Math.min(...shown.map(output => output.y))
            readonly property real boundsW: Math.max(1, Math.max(...shown.map(output => output.x + output.w)) - minX)
            readonly property real boundsH: Math.max(1, Math.max(...shown.map(output => output.y + output.h)) - minY)
            readonly property real ratio: Math.min((width - 48) / boundsW, (height - 48) / boundsH)

            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: 260
            // Tažený monitor nesmí překrýt řádky pod rozložením
            clip: true

            Repeater {
                model: arrangement.shown

                StyledRect {
                    id: screenRect

                    required property var modelData

                    property real dragX: 0
                    property real dragY: 0
                    readonly property bool isSelected: modelData.name === DeskMonitors.selectedName

                    x: (arrangement.width - arrangement.boundsW * arrangement.ratio) / 2 + (modelData.x - arrangement.minX) * arrangement.ratio + dragX
                    y: (arrangement.height - arrangement.boundsH * arrangement.ratio) / 2 + (modelData.y - arrangement.minY) * arrangement.ratio + dragY
                    width: modelData.w * arrangement.ratio - 2
                    height: modelData.h * arrangement.ratio - 2
                    z: dragArea.pressed ? 1 : 0
                    radius: Tokens.rounding.small
                    color: isSelected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
                    border.width: isSelected ? 2 : 0
                    border.color: Colours.palette.m3primary

                    Column {
                        anchors.centerIn: parent

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screenRect.modelData.name
                            color: screenRect.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screenRect.modelData.name === DeskMonitors.mainName ? `${screenRect.modelData.w} × ${screenRect.modelData.h}, main` : `${screenRect.modelData.w} × ${screenRect.modelData.h}`
                            color: screenRect.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }

                    MouseArea {
                        id: dragArea

                        property point pressPoint

                        anchors.fill: parent
                        // Jinak by tažení převzalo rolování stránky a monitor by se nepohnul
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: event => {
                            DeskMonitors.selectedName = screenRect.modelData.name;
                            pressPoint = mapToItem(arrangement, event.x, event.y);
                        }
                        onPositionChanged: event => {
                            const point = mapToItem(arrangement, event.x, event.y);
                            screenRect.dragX = point.x - pressPoint.x;
                            screenRect.dragY = point.y - pressPoint.y;
                        }
                        onReleased: {
                            const moved = Math.abs(screenRect.dragX) + Math.abs(screenRect.dragY) > 3;
                            const x = screenRect.modelData.x + screenRect.dragX / arrangement.ratio;
                            const y = screenRect.modelData.y + screenRect.dragY / arrangement.ratio;
                            screenRect.dragX = 0;
                            screenRect.dragY = 0;
                            if (moved && arrangement.shown.length > 1)
                                DeskMonitors.moveTo(screenRect.modelData.name, x, y);
                        }
                    }
                }
            }
        }

        // Hned pod rozložením: změny se projeví až po použití, tlačítko musí být vidět
        RowButton {
            id: swapButton

            Layout.topMargin: Tokens.spacing.medium
            visible: !DeskMonitors.pending && arrangement.shown.length === 2
            first: true
            icon: "swap_horiz"
            text: "Swap left and right"
            subtext: "Then apply and keep, like after dragging"
            onClicked: DeskMonitors.swapSides()
        }

        RowButton {
            Layout.topMargin: swapButton.visible ? 0 : Tokens.spacing.medium
            visible: !DeskMonitors.pending
            first: !swapButton.visible
            disabled: !DeskMonitors.dirty
            icon: "check"
            text: DeskMonitors.dirty ? "Apply changes" : "No changes to apply"
            subtext: DeskMonitors.dirty ? `You'll have ${DeskMonitors.confirmSeconds} seconds to keep them` : ""
            onClicked: DeskMonitors.apply()
        }

        RowButton {
            visible: !DeskMonitors.pending
            last: true
            disabled: !DeskMonitors.dirty
            icon: "undo"
            text: "Reset"
            onClicked: DeskMonitors.reset()
        }

        RowButton {
            Layout.topMargin: Tokens.spacing.medium
            visible: DeskMonitors.pending
            first: true
            icon: "check"
            text: "Keep changes"
            subtext: DeskMonitors.restartOnKeep ? `The panel moves after you keep them. Going back in ${DeskMonitors.secondsLeft} s` : `Going back in ${DeskMonitors.secondsLeft} s`
            onClicked: DeskMonitors.keep()
        }

        RowButton {
            visible: DeskMonitors.pending
            last: true
            icon: "undo"
            text: "Go back now"
            onClicked: DeskMonitors.revert()
        }

        // Nastavení níže patří monitoru vybranému kliknutím v rozložení nahoře
        InfoRow {
            Layout.topMargin: Tokens.spacing.medium
            first: true
            label: "Settings for"
            subtext: `${root.output?.description ?? ""}. Click a display above to change it`
            value: DeskMonitors.selectedName
        }

        ToggleRow {
            text: "Enabled"
            subtext: DeskMonitors.selectedName === DeskMonitors.mainName ? "The main display can't be turned off" : ""
            disabled: DeskMonitors.selectedName === DeskMonitors.mainName
            checked: !(root.output?.disabled ?? false)
            onToggled: DeskMonitors.setDisabled(DeskMonitors.selectedName, !checked)
        }

        ToggleRow {
            text: "Main display"
            subtext: "Shows the panel"
            // Hlavní monitor se mění zapnutím na jiném, vypnout ho nejde
            disabled: (root.output?.disabled ?? false) || DeskMonitors.selectedName === DeskMonitors.mainName
            checked: DeskMonitors.selectedName === DeskMonitors.mainName
            onToggled: {
                if (checked)
                    DeskMonitors.setMain(DeskMonitors.selectedName);
            }
        }

        SelectRow {
            label: "Resolution"
            menuItems: resolutionVariants.instances
            active: menuItems.find(item => item.text === root.resolution) ?? null
            fallbackText: root.resolution
            onSelected: item => {
                const best = (root.output?.modes ?? []).find(mode => mode.split("@")[0] === item.text);
                if (best)
                    DeskMonitors.reshape(DeskMonitors.selectedName, { mode: best });
            }
        }

        SelectRow {
            label: "Refresh rate"
            menuItems: rateVariants.instances
            active: menuItems.find(item => item.value === root.output?.mode) ?? null
            fallbackText: root.output ? `${Number(root.output.mode.split("@")[1]).toFixed(2)} Hz` : ""
            onSelected: item => DeskMonitors.update(DeskMonitors.selectedName, { mode: item.value })
        }

        SelectRow {
            label: "Scale"
            menuItems: root.scaleItems
            active: menuItems.find(item => item.value === root.output?.scale) ?? null
            fallbackText: root.output ? `${Math.round(root.output.scale * 100)} %` : ""
            onSelected: item => DeskMonitors.reshape(DeskMonitors.selectedName, { scale: item.value })
        }

        SelectRow {
            last: true
            menuOnTop: true
            label: "Rotation"
            menuItems: root.rotationItems
            active: menuItems.find(item => item.value === root.output?.transform) ?? null
            fallbackText: "None"
            onSelected: item => DeskMonitors.reshape(DeskMonitors.selectedName, { transform: item.value })
        }

    }
}
