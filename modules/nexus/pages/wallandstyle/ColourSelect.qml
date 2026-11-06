pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // Prostředí desk: pevná schémata (desk/season-scheme.py) nebo barvy z tapety
    readonly property var deskSchemes: [
        { id: "season-simpleton", icon: "water_drop", text: "Simpleton", subtext: "Calm blue", command: [`${ShellEnv.deskDir}/season-scheme.py`, "simpleton"] },
        { id: "season-simpleton-test", icon: "contrast", text: "Simpleton Test", subtext: "Simpleton with a lighter background", command: [`${ShellEnv.deskDir}/season-scheme.py`, "simpleton-test"] },
        { id: "season-spring", icon: "local_florist", text: "Spring", subtext: "Warm pastel green", command: [`${ShellEnv.deskDir}/season-scheme.py`, "spring"] },
        { id: "season-summer", icon: "wb_sunny", text: "Summer", subtext: "Warm pastel yellow", command: [`${ShellEnv.deskDir}/season-scheme.py`, "summer"] },
        { id: "season-autumn", icon: "park", text: "Autumn", subtext: "Warm pastel brown", command: [`${ShellEnv.deskDir}/season-scheme.py`, "autumn"] },
        { id: "season-winter", icon: "ac_unit", text: "Winter", subtext: "Warm white", command: [`${ShellEnv.deskDir}/season-scheme.py`, "winter"] },
        { id: "dynamic", icon: "wallpaper", text: "From wallpaper", subtext: "Colours follow the wallpaper", command: ["caelestia", "scheme", "set", "-n", "dynamic"] }
    ]

    readonly property JsonFile currentScheme: JsonFile {
        path: ShellEnv.isDesk ? `${Paths.state}/scheme.json` : ""
    }

    title: Tr.tr("Colours")
    isSubPage: true

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cappedWidth
        implicitHeight: {
            const f = parent.parent as Flickable;
            return f.height - f.topMargin - f.bottomMargin;
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: ShellEnv.isDesk
            spacing: Tokens.spacing.extraSmall / 2

            Repeater {
                model: root.deskSchemes

                RowButton {
                    required property var modelData
                    required property int index

                    first: index === 0
                    last: index === root.deskSchemes.length - 1
                    icon: modelData.icon
                    text: modelData.text
                    subtext: modelData.subtext
                    trailingIcon: root.currentScheme.value?.name === modelData.id ? "check" : ""
                    onClicked: Quickshell.execDetached(modelData.command)
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: !ShellEnv.isDesk
            spacing: Tokens.padding.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "handyman"
                color: Colours.palette.m3outlineVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("Page under construction")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.title.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("This page will be available in a future update.")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.body.large
            }
        }
    }
}
