import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Vnořená položka pod krytím panelu: drží jeho hodnotu, dokud ji uživatel nenastaví zvlášť. Tlačítko ji zase spojí.
ColumnLayout {
    id: root

    required property string icon
    required property string label
    // DeskPanelSettings.LinkedOpacity
    required property QtObject item

    readonly property real sliderValue: (item.value - DeskPanelSettings.minPanelOpacity) / (DeskPanelSettings.maxPanelOpacity - DeskPanelSettings.minPanelOpacity)

    function moveTo(value: real): void {
        item.set(DeskPanelSettings.minPanelOpacity + value * (DeskPanelSettings.maxPanelOpacity - DeskPanelSettings.minPanelOpacity));
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: root.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            Layout.fillWidth: true
            text: root.label
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }

        StyledText {
            text: `${root.item.value} %`
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        IconButton {
            type: IconButton.Tonal
            isToggle: true
            checked: root.item.linked
            padding: Tokens.padding.extraSmall
            font: Tokens.font.icon.small
            icon: root.item.linked ? "link" : "link_off"
            onClicked: root.item.setLinked(!root.item.linked)
        }
    }

    CustomMouseArea {
        function onWheel(event: WheelEvent): void {
            const step = GlobalConfig.services.audioIncrement;
            if (event.angleDelta.y > 0)
                root.moveTo(Math.min(1, root.sliderValue + step));
            else if (event.angleDelta.y < 0)
                root.moveTo(Math.max(0, root.sliderValue - step));
        }

        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 1.5

        StyledSlider {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: parent.implicitHeight

            radius: Tokens.rounding.extraSmall
            value: root.sliderValue
            onInteraction: v => root.moveTo(v)
        }
    }
}
