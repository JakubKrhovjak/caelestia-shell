import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

// Horní panel prostředí desk na stránce Panels. Ve vlastním souboru, ať je změna v upstreamové stránce co nejmenší.
ColumnLayout {
    spacing: Tokens.spacing.extraSmall / 2

    SliderRow {
        first: true
        icon: "height"
        label: "Panel height"
        valueLabel: `${DeskPanelSettings.panelHeight} px`
        value: (DeskPanelSettings.panelHeight - DeskPanelSettings.minPanelHeight) / (DeskPanelSettings.maxPanelHeight - DeskPanelSettings.minPanelHeight)
        onMoved: value => DeskPanelSettings.setPanelHeight(DeskPanelSettings.minPanelHeight + value * (DeskPanelSettings.maxPanelHeight - DeskPanelSettings.minPanelHeight))
    }

    SliderRow {
        icon: "photo_size_select_small"
        label: "Icon size"
        valueLabel: `${DeskPanelSettings.iconSize} px`
        value: (DeskPanelSettings.requestedIconSize - DeskPanelSettings.minIconSize) / (DeskPanelSettings.maxIconSize - DeskPanelSettings.minIconSize)
        onMoved: value => DeskPanelSettings.setIconSize(DeskPanelSettings.minIconSize + value * (DeskPanelSettings.maxIconSize - DeskPanelSettings.minIconSize))
    }

    SliderRow {
        icon: "more_horiz"
        label: "Tray icon size"
        valueLabel: `${DeskPanelSettings.trayIconSize} px`
        value: (DeskPanelSettings.requestedTrayIconSize - DeskPanelSettings.minIconSize) / (DeskPanelSettings.maxIconSize - DeskPanelSettings.minIconSize)
        onMoved: value => DeskPanelSettings.setTrayIconSize(DeskPanelSettings.minIconSize + value * (DeskPanelSettings.maxIconSize - DeskPanelSettings.minIconSize))
    }

    // Krytí panelu a to, co ho přebírá, tvoří jednu dlaždici; další položka je další řádek
    ConnectedRect {
        last: true
        Layout.fillWidth: true
        implicitHeight: opacityColumn.implicitHeight

        ColumnLayout {
            id: opacityColumn

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            SliderRow {
                color: "transparent"
                icon: "opacity"
                label: "Panel opacity"
                valueLabel: `${DeskPanelSettings.panelOpacity} %`
                value: (DeskPanelSettings.panelOpacity - DeskPanelSettings.minPanelOpacity) / (DeskPanelSettings.maxPanelOpacity - DeskPanelSettings.minPanelOpacity)
                onMoved: value => DeskPanelSettings.setPanelOpacity(DeskPanelSettings.minPanelOpacity + value * (DeskPanelSettings.maxPanelOpacity - DeskPanelSettings.minPanelOpacity))
            }

            ColumnLayout {
                Layout.fillWidth: true
                // Začátek posuvníku panelu: odsazení řádku, jeho ikona a mezera
                Layout.leftMargin: Tokens.padding.largeIncreased * 2.5 + 6
                Layout.rightMargin: Tokens.padding.largeIncreased
                Layout.bottomMargin: Tokens.padding.large
                spacing: Tokens.spacing.medium

                DeskLinkedOpacityRow {
                    icon: "web_asset"
                    label: "Window title bars"
                    item: DeskPanelSettings.windowBars
                }

                DeskLinkedOpacityRow {
                    icon: "terminal"
                    label: "Ghostty"
                    item: DeskPanelSettings.ghostty
                }
            }
        }
    }
}
