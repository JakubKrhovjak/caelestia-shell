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
        last: true
        icon: "photo_size_select_small"
        label: "Icon size"
        valueLabel: `${DeskPanelSettings.iconSize} px`
        value: (DeskPanelSettings.requestedIconSize - DeskPanelSettings.minIconSize) / (DeskPanelSettings.maxIconSize - DeskPanelSettings.minIconSize)
        onMoved: value => DeskPanelSettings.setIconSize(DeskPanelSettings.minIconSize + value * (DeskPanelSettings.maxIconSize - DeskPanelSettings.minIconSize))
    }
}
