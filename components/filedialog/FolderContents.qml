pragma ComponentBehavior: Bound

// Obsah složky jako seznam (Dolphin „Details“): ikona | jméno | typ | velikost.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

// FocusScope: aktivace panelu (Pane.activate) předá fokus seznamu, jinak by jeho klávesy nedostaly žádný stisk
FocusScope {
    id: root

    required property var dialog
    readonly property FileEntry currentItem: view.currentItem as FileEntry

    readonly property real typeWidth: 150
    readonly property real sizeWidth: 90
    // V úzkém panelu by na název nezbylo místo; typ souboru je vidět i z ikony
    readonly property bool showType: width >= 480

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

    readonly property string currentPath: dialog.cwd[0] === "Home"
        ? Paths.home + `/${dialog.cwd.slice(1).join("/")}`
        : dialog.cwd.join("/").replace(/^\/+/, "/")

    // Přenese soubory (URL z drag&drop) do složky dest: Shift = přesun, jinak kopie (jako Dolphin)
    function transfer(urls: list<url>, dest: string, move: bool): void {
        const srcs = urls.map(u => decodeURIComponent(u.toString().replace(/^file:\/\//, "")))
            .filter(src => src !== dest && !dest.startsWith(src + "/") && src.slice(0, src.lastIndexOf("/")) !== dest);
        if (srcs.length > 0)
            Quickshell.execDetached(move ? ["mv", "-n", "--", ...srcs, dest] : ["cp", "-rn", "--", ...srcs, dest]);
    }

    // Přejmenovávaný soubor a jméno, které se po vzniku v seznamu vybere (nová složka, přejmenování)
    property string editingPath: ""
    property string pendingSelect: ""
    property bool renamePending: false

    // Mazání jen do koše, aby nic nezmizelo natrvalo; chyby hlásí oznámení, příkazy běží mimo shell
    function trash(file: FileSystemEntry): void {
        Quickshell.execDetached(["sh", "-c", 'gio trash -- "$1" || notify-send "Files" "Could not move to trash: $1"', "sh", file.path]);
    }

    function rename(file: FileSystemEntry, name: string): void {
        editingPath = "";
        view.forceActiveFocus();
        if (!name || name === file.name || name.includes("/"))
            return;
        const dest = file.path.slice(0, file.path.lastIndexOf("/") + 1) + name;
        Quickshell.execDetached(["sh", "-c", 'if [ -e "$2" ]; then notify-send "Files" "Already exists: $2"; else mv -- "$1" "$2" || notify-send "Files" "Could not rename: $1"; fi', "sh", file.path, dest]);
        pendingSelect = name;
    }

    function newFolder(): void {
        newFolderProc.command = ["sh", "-c", 'n="New Folder"; i=2; while [ -e "$1/$n" ]; do n="New Folder $i"; i=$((i + 1)); done; mkdir -- "$1/$n" && printf %s "$n"', "sh", currentPath];
        newFolderProc.running = true;
    }

    // Vybere položku podle jména; delegát, který vznikne až později, si to zkontroluje sám
    function selectPending(entry: var): bool {
        if (!pendingSelect || entry.modelData.name !== pendingSelect)
            return false;
        view.currentIndex = entry.index;
        if (renamePending)
            editingPath = entry.modelData.path;
        pendingSelect = "";
        renamePending = false;
        return true;
    }

    onPendingSelectChanged: {
        for (let i = 0; i < view.count; i++) {
            const entry = view.itemAtIndex(i);
            if (entry && selectPending(entry))
                return;
        }
    }

    Process {
        id: newFolderProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    root.renamePending = true;
                    root.pendingSelect = text;
                }
            }
        }
    }

    function open(file: FileSystemEntry): void {
        if (file.isDir)
            dialog.cwd.push(file.name);
        else if (dialog.selectionValid)
            dialog.accepted(file.path);
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3surfaceContainer

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
            visible: root.showType
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
            const ctrl = event.modifiers & Qt.ControlModifier;
            const file = currentItem ? (currentItem as FileEntry).modelData : null;
            // Jako na Macu: Cmd + Backspace do koše, Cmd + Shift + N nová složka; F2 přejmenuje
            if (file && (event.key === Qt.Key_Delete || (ctrl && event.key === Qt.Key_Backspace))) {
                root.trash(file);
                event.accepted = true;
            } else if (file && event.key === Qt.Key_F2) {
                root.editingPath = file.path;
                event.accepted = true;
            } else if (ctrl && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_N) {
                root.newFolder();
                event.accepted = true;
            } else if (ctrl && event.key === Qt.Key_T) {
                root.dialog.newTab();
                event.accepted = true;
            } else if (ctrl && event.key === Qt.Key_W) {
                root.dialog.closeTab(root.dialog.currentTab);
                event.accepted = true;
            } else if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                root.dialog.nextTab();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace && root.dialog.cwd.length > 1) {
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
            path: root.currentPath
            watchChanges: true
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

    // Drop do prázdného místa seznamu = do aktuální složky
    DropArea {
        id: folderDrop

        anchors.fill: view
        keys: ["text/uri-list"]
        onEntered: drag => drag.accept(drag.proposedAction)
        onDropped: drop => {
            root.transfer(drop.urls, root.currentPath, drop.action === Qt.MoveAction);
            drop.accept(drop.action);
        }
    }

    StyledRect {
        anchors.fill: view
        radius: Tokens.rounding.medium
        color: "transparent"
        border.width: 2
        border.color: Qt.alpha(Colours.palette.m3primary, folderDrop.containsDrag ? 0.8 : 0)
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
        readonly property bool editing: root.editingPath === modelData.path

        Component.onCompleted: root.selectPending(item)

        width: ListView.view.width - Tokens.padding.small
        implicitHeight: row.implicitHeight + Tokens.padding.small * 2

        radius: Tokens.rounding.small
        color: rowDrop.containsDrag ? Qt.alpha(Colours.palette.m3primary, 0.25)
             : current ? Colours.palette.m3secondaryContainer
             : (index % 2 ? Qt.alpha(Colours.palette.m3onSurface, 0.025) : "transparent")

        // Neviditelný „nosič“ systémového dragu – funguje i do jiných aplikací
        Item {
            id: dragProxy

            width: item.width
            height: item.height
            Drag.active: rowLayer.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.proposedAction: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": "file://" + encodeURI(item.modelData.path) + "\r\n" })
            Drag.onDragFinished: {
                dragProxy.x = 0;
                dragProxy.y = 0;
            }
        }

        // Při stisknutí vyfotí řádek – ten obrázek pak jede s myší během přetahování
        Connections {
            target: rowLayer

            function onPressed(mouse: MouseEvent): void {
                dragProxy.Drag.hotSpot.x = mouse.x;
                dragProxy.Drag.hotSpot.y = mouse.y;
                item.grabToImage(result => dragProxy.Drag.imageSource = result.url);
            }
        }

        // Drop na složku = do té složky
        DropArea {
            id: rowDrop

            anchors.fill: parent
            enabled: item.modelData.isDir
            keys: ["text/uri-list"]
            onEntered: drag => drag.accept(drag.proposedAction)
            onDropped: drop => {
                root.transfer(drop.urls, item.modelData.path, drop.action === Qt.MoveAction);
                drop.accept(drop.action);
            }
        }

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            id: rowLayer

            radius: item.radius
            drag.target: dragProxy
            drag.threshold: 8
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
                visible: !item.editing
                Layout.fillWidth: true
                text: item.modelData.name
                elide: Text.ElideMiddle
                color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }

            // Přejmenování přímo v řádku: Enter potvrdí, Escape nebo kliknutí jinam zruší
            TextInput {
                id: nameInput

                visible: item.editing
                Layout.fillWidth: true
                clip: true
                selectByMouse: true
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary
                font: Tokens.font.body.small

                onVisibleChanged: {
                    if (!visible)
                        return;
                    const name = item.modelData.name;
                    const dot = name.lastIndexOf(".");
                    text = name;
                    forceActiveFocus();
                    // Jako ve správcích souborů: označí se jméno bez přípony
                    select(0, item.modelData.isDir || dot <= 0 ? name.length : dot);
                }
                onActiveFocusChanged: {
                    if (!activeFocus && item.editing)
                        root.editingPath = "";
                }
                Keys.onReturnPressed: root.rename(item.modelData, text)
                Keys.onEnterPressed: root.rename(item.modelData, text)
                Keys.onEscapePressed: {
                    root.editingPath = "";
                    view.forceActiveFocus();
                }
            }

            StyledText {
                visible: root.showType
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
