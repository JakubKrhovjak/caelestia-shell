pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

LazyLoader {
    id: loader

    property list<string> cwd: ["Home"]
    property string filterLabel: Tr.tr("All files")
    property list<string> filters: ["*"]
    property string title: Tr.tr("Select a file")

    signal accepted(path: string)
    signal rejected

    // Složka, kterou má nově otevřené okno ukázat
    property string pendingPath: ""

    function open(): void {
        activeAsync = true;
    }

    // Absolutní cesta → cwd ve formátu dialogu (["Home", …] nebo ["/", …])
    function pathToCwd(path: string): list<string> {
        if (path === Paths.home)
            return ["Home"];
        if (path.startsWith(Paths.home + "/"))
            return ["Home", ...path.slice(Paths.home.length + 1).split("/").filter(Boolean)];
        return ["/", ...path.split("/").filter(Boolean)];
    }

    // Ukáže složku v aktivním panelu; cesta může být i ve tvaru file://, jen ten je procentově kódovaný
    function openPath(path: string): void {
        const local = path.startsWith("file://") ? decodeURIComponent(path.slice("file://".length)) : path;
        const clean = local.replace(/\/+$/, "") || "/";
        if (item) {
            (item as FloatingWindow).showCwd(pathToCwd(clean));
        } else {
            pendingPath = clean;
            activeAsync = true;
        }
    }

    function close(): void {
        if (item)
            (item as FloatingWindow).rejected(); // uloží stav
        else
            rejected();
    }

    onAccepted: activeAsync = false
    onRejected: activeAsync = false

    FloatingWindow {
        id: root

        property string filterLabel: loader.filterLabel
        property list<string> filters: loader.filters

        // Dva panely jako v Dolphinu; sidebar a tlačítka pracují s aktivním (naposledy kliknutým)
        property var activePane: leftPane
        readonly property bool selectionValid: activePane.selectionValid

        function accepted(path: string): void {
            saveState();
            loader.accepted(path);
        }

        function rejected(): void {
            saveState();
            loader.rejected();
        }

        // Stav (složky v panelech, aktivní panel, velikost) – obnoví se při dalším otevření
        function saveState(): void {
            dialogState.leftTabs = leftPane.allTabs().map(t => JSON.stringify(t));
            dialogState.rightTabs = rightPane.allTabs().map(t => JSON.stringify(t));
            dialogState.leftTab = leftPane.currentTab;
            dialogState.rightTab = rightPane.currentTab;
            dialogState.activeRight = activePane === rightPane;
            dialogState.sidebarWidth = sidebar.width;
            dialogState.width = root.width;
            dialogState.height = root.height;
            stateFile.writeAdapter();
        }

        FileView {
            id: stateFile

            path: `${Paths.state}/file-dialog.json`
            blockLoading: true
            blockWrites: true

            JsonAdapter {
                id: dialogState

                property list<string> left: [] // starší formát (jen jeden tab)
                property list<string> right: []
                property list<string> leftTabs: [] // každý tab = JSON pole cwd
                property list<string> rightTabs: []
                property int leftTab: 0
                property int rightTab: 0
                property bool activeRight: false
                property int sidebarWidth: 230
                property int width: 1400
                property int height: 700
            }
        }

        Component.onCompleted: {
            if (dialogState.leftTabs.length > 0)
                leftPane.restoreTabs(dialogState.leftTabs.map(t => JSON.parse(t)), dialogState.leftTab);
            else if (dialogState.left.length > 0)
                leftPane.restoreTabs([Array.from(dialogState.left)], 0);
            if (dialogState.rightTabs.length > 0)
                rightPane.restoreTabs(dialogState.rightTabs.map(t => JSON.parse(t)), dialogState.rightTab);
            else if (dialogState.right.length > 0)
                rightPane.restoreTabs([Array.from(dialogState.right)], 0);
            if (dialogState.activeRight)
                activePane = rightPane;
            if (loader.pendingPath) {
                showCwd(loader.pathToCwd(loader.pendingPath));
                loader.pendingPath = "";
            }
        }

        function pathToCwd(path: string): list<string> {
            return loader.pathToCwd(path);
        }

        // Už otevřenou složku jen vybere, jinak přidá záložku
        function showCwd(target: var): void {
            const open = activePane.allTabs();
            const existing = open.findIndex(tab => JSON.stringify(Array.from(tab)) === JSON.stringify(Array.from(target)));
            if (existing >= 0)
                activePane.restoreTabs(open, existing);
            else
                activePane.restoreTabs([...open, target], open.length);
        }

        function switchPane(): void {
            (activePane === leftPane ? rightPane : leftPane).activate();
        }

        implicitWidth: dialogState.width
        implicitHeight: dialogState.height
        minimumSize.width: 400
        minimumSize.height: 300
        color: Colours.tPalette.m3surface
        surfaceFormat.opaque: false
        title: loader.title

        onVisibleChanged: {
            if (!visible)
                rejected();
        }

        RowLayout {
            anchors.fill: parent

            spacing: 0

            Sidebar {
                id: sidebar

                Layout.fillHeight: true
                Layout.preferredWidth: dialogState.sidebarWidth
                dialog: root.activePane
            }

            // Úchyt pro změnu šířky sidebaru (táhni myší)
            Item {
                Layout.fillHeight: true
                implicitWidth: 6

                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: 40
                    radius: 1
                    color: Colours.palette.m3outlineVariant
                    opacity: resizeArea.containsMouse || resizeArea.pressed ? 1 : 0.4

                    Behavior on opacity {
                        Anim {}
                    }
                }

                MouseArea {
                    id: resizeArea

                    property real startX
                    property real startWidth

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    onPressed: mouse => {
                        startX = mapToItem(null, mouse.x, 0).x;
                        startWidth = sidebar.width;
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            dialogState.sidebarWidth = Math.max(140, Math.min(500, startWidth + mapToItem(null, mouse.x, 0).x - startX));
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Pane {
                        id: leftPane

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        dialog: root
                        cwd: loader.cwd
                    }

                    Pane {
                        id: rightPane

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        dialog: root
                    }
                }

                DialogButtons {
                    Layout.fillWidth: true
                    dialog: root.activePane
                    folder: root.activePane.folder
                }
            }
        }

        Behavior on color {
            CAnim {}
        }
    }
}
