pragma ComponentBehavior: Bound

// Sidebar výběru souborů: Místa (výchozí + vlastní záložky) a Disky.
// Záložky: „+“ přidá složku otevřenou v aktivním panelu, pravý klik záložku odebere.
// Ukládají se do ~/.config/caelestia/file-bookmarks.json.

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.filedialog
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var dialog // aktivní Pane
    readonly property string currentPath: dialog.folder.currentPath

    readonly property var defaultPlaces: [
        { name: "Home", icon: "home", path: Paths.home },
        { name: "Downloads", icon: "file_download", path: `${Paths.home}/Downloads` },
        { name: "Desktop", icon: "desktop_windows", path: `${Paths.home}/Desktop` },
        { name: "Documents", icon: "description", path: `${Paths.home}/Documents` },
        { name: "Music", icon: "music_note", path: `${Paths.home}/Music` },
        { name: "Pictures", icon: "image", path: `${Paths.home}/Pictures` },
        { name: "Videos", icon: "video_library", path: `${Paths.home}/Videos` }
    ]

    property var disks: []

    // Absolutní cesta → cwd ve formátu dialogu (["Home", …] nebo ["/", …])
    function pathToCwd(path: string): list<string> {
        if (path === Paths.home)
            return ["Home"];
        if (path.startsWith(Paths.home + "/"))
            return ["Home", ...path.slice(Paths.home.length + 1).split("/").filter(Boolean)];
        return ["/", ...path.split("/").filter(Boolean)];
    }

    function go(path: string): void {
        dialog.cwd = pathToCwd(path);
    }

    function normalize(path: string): string {
        return path.replace(/^\/+/, "/").replace(/\/+$/, "") || "/";
    }

    function addBookmark(): void {
        const p = normalize(currentPath);
        if (p !== Paths.home && !bookmarks.paths.includes(p) && !defaultPlaces.some(d => d.path === p))
            bookmarks.paths = [...bookmarks.paths, p];
    }

    function removeBookmark(path: string): void {
        bookmarks.paths = bookmarks.paths.filter(p => p !== path);
    }

    implicitWidth: Sizes.sidebarWidth
    implicitHeight: inner.implicitHeight + Tokens.padding.medium * 2

    color: Colours.tPalette.m3surfaceContainer

    FileView {
        path: `${Paths.config}/file-bookmarks.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: bookmarks

            property list<string> paths: []
        }
    }

    // Připojené disky (jeden řádek na zařízení; btrfs subvolumy sloučí)
    Process {
        running: true
        command: ["findmnt", "-J", "-l", "-b", "-o", "TARGET,SOURCE,FSTYPE,LABEL,SIZE,USED",
            "-t", "ext4,btrfs,xfs,vfat,exfat,ntfs,ntfs3,f2fs,fuseblk"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                const fss = JSON.parse(text).filesystems.filter(fs => !fs.target.startsWith("/boot"))
                    .sort((a, b) => a.target.length - b.target.length);
                for (const fs of fss) {
                    const dev = fs.source.replace(/\[.*\]$/, "");
                    if (seen[dev])
                        continue;
                    seen[dev] = true;
                    out.push({
                        path: fs.target,
                        name: fs.label || (fs.target === "/" ? Tr.tr("System") : fs.target.split("/").pop()),
                        used: fs.size > 0 ? fs.used / fs.size : 0,
                        size: fs.size
                    });
                }
                root.disks = out;
            }
        }
    }

    StyledFlickable {
        id: flick

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        contentWidth: width
        contentHeight: inner.implicitHeight
        clip: true

        ColumnLayout {
            id: inner

            width: flick.width // šířka sidebaru, ne obsahu – jinak se zaoblení useknou
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.padding.extraSmall / 2
                Layout.bottomMargin: Tokens.spacing.medium
                text: Tr.trCtx("Files", "file dialog sidebar heading")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.builders.large.weight(Font.Bold).build()
            }

            Repeater {
                model: root.defaultPlaces

                Place {
                    required property var modelData

                    name: modelData.name
                    icon: modelData.icon
                    path: modelData.path
                }
            }

            // --- Vlastní záložky ---
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.medium
                Layout.leftMargin: Tokens.padding.large

                SectionTitle {
                    Layout.fillWidth: true
                    text: Tr.tr("Bookmarks")
                }

                Item {
                    implicitWidth: implicitHeight
                    implicitHeight: addIcon.implicitHeight + Tokens.padding.small

                    StateLayer {
                        radius: Tokens.rounding.full
                        onClicked: root.addBookmark()
                    }

                    MaterialIcon {
                        id: addIcon

                        anchors.centerIn: parent
                        text: "add"
                        color: Colours.palette.m3primary
                    }
                }
            }

            StyledText {
                Layout.leftMargin: Tokens.padding.large
                visible: bookmarks.paths.length === 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Tr.tr("+ adds the open folder")
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }

            Repeater {
                model: bookmarks.paths

                Place {
                    required property string modelData

                    name: modelData.split("/").pop() || "/"
                    icon: "folder"
                    path: modelData
                    removable: true
                }
            }

            // --- Disky ---
            SectionTitle {
                Layout.topMargin: Tokens.spacing.medium
                Layout.leftMargin: Tokens.padding.large
                text: Tr.tr("Devices")
                visible: root.disks.length > 0
            }

            Repeater {
                model: root.disks

                Place {
                    required property var modelData

                    name: modelData.name
                    icon: "hard_drive"
                    path: modelData.path
                    usage: modelData.used
                }
            }
        }
    }

    component SectionTitle: StyledText {
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.builders.small.weight(Font.Bold).build()
    }

    component Place: StyledRect {
        id: place

        property string name
        property string icon
        property string path
        property bool removable
        property real usage: -1
        readonly property bool selected: root.normalize(root.currentPath) === path

        Layout.fillWidth: true
        implicitHeight: placeInner.implicitHeight + Tokens.padding.medium * 2

        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3secondaryContainer, selected ? 1 : 0)

        StateLayer {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (place.removable)
                        root.removeBookmark(place.path);
                } else {
                    root.go(place.path);
                }
            }
        }

        // drop souborů na místo = kopie do něj (Shift = přesun)
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => drag.accept(drag.proposedAction)
            onDropped: drop => {
                root.dialog.folder.transfer(drop.urls, place.path, drop.action === Qt.MoveAction);
                drop.accept(drop.action);
            }
        }

        RowLayout {
            id: placeInner

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large

            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: place.icon
                color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.medium
                fill: place.selected ? 1 : 0

                Behavior on fill {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: place.name
                    color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                // zaplnění disku
                StyledRect {
                    Layout.fillWidth: true
                    visible: place.usage >= 0
                    implicitHeight: 4
                    radius: 2
                    color: Colours.palette.m3surfaceContainerHighest

                    StyledRect {
                        width: parent.width * Math.max(0, place.usage)
                        height: parent.height
                        radius: 2
                        color: place.usage > 0.9 ? Colours.palette.m3error : Colours.palette.m3primary
                    }
                }
            }
        }
    }
}
