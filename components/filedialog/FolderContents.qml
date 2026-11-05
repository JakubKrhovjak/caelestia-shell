pragma ComponentBehavior: Bound

// Obsah složky jako seznam (Dolphin „Details“): ikona | jméno | typ | velikost.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property var dialog
    readonly property FileEntry currentItem: view.currentItem as FileEntry

    readonly property real typeWidth: 150
    readonly property real sizeWidth: 90

    function formatSize(bytes: real): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return `${i === 0 ? bytes : bytes.toFixed(1)} ${units[i]}`;
    }

    function typeOf(file: FileSystemEntry): string {
        if (file.isDir)
            return Tr.tr("Folder");
        return file.suffix ? file.suffix.toUpperCase() : file.mimeType;
    }

    function open(file: FileSystemEntry): void {
        if (file.isDir)
            dialog.cwd.push(file.name);
        else if (dialog.selectionValid)
            dialog.accepted(file.path);
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.tPalette.m3surfaceContainer

        layer.enabled: true
        layer.effect: Mask {
            maskSource: mask
            maskInverted: true
        }
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall
            radius: Tokens.rounding.medium
        }
    }

    // Hlavička sloupců
    RowLayout {
        id: columns

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.extraSmall + Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.extraSmall + Tokens.padding.large
        anchors.rightMargin: Tokens.padding.extraSmall + Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 22 + Tokens.spacing.medium
            text: Tr.tr("Name")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.builders.small.weight(Font.Bold).build()
        }

        StyledText {
            Layout.preferredWidth: root.typeWidth
            text: Tr.tr("Type")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.builders.small.weight(Font.Bold).build()
        }

        StyledText {
            Layout.preferredWidth: root.sizeWidth
            horizontalAlignment: Text.AlignRight
            text: Tr.tr("Size")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.builders.small.weight(Font.Bold).build()
        }
    }

    Rectangle {
        id: divider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: columns.bottom
        anchors.topMargin: Tokens.spacing.small
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent

        opacity: view.count === 0 ? 1 : 0
        active: opacity > 0

        sourceComponent: ColumnLayout {
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "scan_delete"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).weight(Font.Medium).build()
            }

            StyledText {
                text: Tr.tr("This folder is empty")
                color: Colours.palette.m3outline
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    ListView {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: divider.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.extraSmall + Tokens.padding.small
        anchors.topMargin: Tokens.spacing.small

        spacing: 1
        clip: true
        focus: true
        currentIndex: -1
        highlightMoveDuration: 0
        keyNavigationEnabled: true

        Keys.onEscapePressed: currentIndex = -1
        Keys.onReturnPressed: if (currentItem) root.open((currentItem as FileEntry).modelData)
        Keys.onEnterPressed: if (currentItem) root.open((currentItem as FileEntry).modelData)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace && root.dialog.cwd.length > 1) {
                root.dialog.cwd.pop();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                root.dialog.switchPane();
                event.accepted = true;
            }
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: view
        }

        model: FileSystemModel {
            path: {
                if (root.dialog.cwd[0] === "Home")
                    return Paths.home + `/${root.dialog.cwd.slice(1).join("/")}`;
                else
                    return root.dialog.cwd.join("/");
            }
            onPathChanged: view.currentIndex = -1
        }

        delegate: FileEntry {}

        add: Transition {
            Anim {
                type: Anim.DefaultEffects
                property: "opacity"
                from: 0
                to: 1
            }
        }

        displaced: Transition {
            Anim {
                property: "y"
            }
        }
    }

    CurrentItem {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.extraSmall

        currentItem: view.currentItem
    }

    component FileEntry: StyledRect {
        id: item

        required property int index
        required property FileSystemEntry modelData
        readonly property bool current: ListView.isCurrentItem

        width: ListView.view.width - Tokens.padding.small
        implicitHeight: row.implicitHeight + Tokens.padding.small * 2

        radius: Tokens.rounding.small
        color: current ? Colours.palette.m3secondaryContainer : (index % 2 ? Qt.alpha(Colours.palette.m3onSurface, 0.025) : "transparent")

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            radius: item.radius
            color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            onClicked: {
                root.dialog.activate();
                view.currentIndex = item.index;
            }
            onDoubleClicked: root.open(item.modelData)
        }

        RowLayout {
            id: row

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            CachingIconImage {
                implicitSize: 22

                Component.onCompleted: {
                    const file = item.modelData;
                    if (file.isImage)
                        source = Qt.resolvedUrl(file.path);
                    else if (!file.isDir)
                        source = Quickshell.iconPath(file.mimeType.replace("/", "-"), "application-x-zerosize");
                    else if (root.dialog.cwd.length === 1 && ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Public", "Templates", "Videos"].includes(file.name))
                        source = Quickshell.iconPath(`folder-${file.name.toLowerCase()}`);
                    else
                        source = Quickshell.iconPath("inode-directory");
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: item.modelData.name
                elide: Text.ElideMiddle
                color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }

            StyledText {
                Layout.preferredWidth: root.typeWidth
                text: root.typeOf(item.modelData)
                elide: Text.ElideRight
                color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            StyledText {
                Layout.preferredWidth: root.sizeWidth
                horizontalAlignment: Text.AlignRight
                text: item.modelData.isDir ? "—" : root.formatSize(item.modelData.size)
                color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }
    }
}
