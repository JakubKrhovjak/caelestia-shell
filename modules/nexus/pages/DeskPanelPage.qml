pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

// Stránka velikosti panelu v Nexusu; v menu je jen v prostředí desk (viz PageRegistry).
PageBase {
    id: root

    title: "Top panel"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
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
}
