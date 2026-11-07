pragma ComponentBehavior: Bound

// Jeden panel výběru souborů (jako panel v Dolphinu): vlastní cesta, hlavička s cestou a seznam.
// Pro HeaderBar/FolderContents/Sidebar/DialogButtons se tváří jako "dialog" (cwd, filters, selectionValid…).

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property var dialog
    property list<string> cwd: ["Home"]
    readonly property bool active: dialog.activePane === root
    readonly property alias folder: folderContents

    readonly property string filterLabel: dialog.filterLabel
    readonly property list<string> filters: dialog.filters
    readonly property bool selectionValid: {
        const file = folderContents.currentItem?.modelData;
        return (file && !file.isDir && (filters.includes("*") || filters.some(filter => filter.toLowerCase() === file.suffix.toLowerCase()))) ?? false;
    }

    function accepted(path: string): void {
        dialog.accepted(path);
    }

    function rejected(): void {
        dialog.rejected();
    }

    function switchPane(): void {
        dialog.switchPane();
    }

    function activate(): void {
        dialog.activePane = root;
        folderContents.forceActiveFocus();
    }

    // --- Taby: tabs[i] = cwd tabu; u aktuálního tabu je živá hodnota v `cwd` ---
    property var tabs: [["Home"]]
    property int currentTab: 0

    function tabCwd(i: int): list<string> {
        return i === currentTab ? cwd : tabs[i];
    }

    function tabName(i: int): string {
        const c = tabCwd(i);
        return c[c.length - 1] ?? "";
    }

    function syncTab(): void {
        const t = tabs.slice();
        t[currentTab] = Array.from(cwd);
        tabs = t;
    }

    function selectTab(i: int): void {
        if (i === currentTab || i < 0 || i >= tabs.length)
            return;
        syncTab();
        currentTab = i;
        cwd = tabs[i];
        activate();
    }

    function newTab(): void {
        syncTab();
        const t = tabs.slice();
        t.splice(currentTab + 1, 0, Array.from(cwd));
        tabs = t;
        currentTab++;
        activate();
    }

    function closeTab(i: int): void {
        if (tabs.length <= 1)
            return;
        syncTab();
        const t = tabs.slice();
        t.splice(i, 1);
        tabs = t;
        currentTab = Math.min(i < currentTab ? currentTab - 1 : currentTab, t.length - 1);
        cwd = tabs[currentTab];
        activate();
    }

    function nextTab(): void {
        selectTab((currentTab + 1) % tabs.length);
    }

    // pro uložení stavu: všechny taby včetně živého cwd
    function allTabs(): var {
        syncTab();
        return tabs;
    }

    function restoreTabs(saved: var, current: int): void {
        if (!saved || saved.length === 0)
            return;
        tabs = saved;
        currentTab = Math.max(0, Math.min(current, saved.length - 1));
        cwd = tabs[currentTab];
    }

    color: "transparent"
    radius: Tokens.rounding.medium
    border.width: 2
    border.color: Qt.alpha(Colours.palette.m3primary, active ? 0.6 : 0)

    Behavior on border.color {
        CAnim {}
    }

    // klik kamkoli do panelu = aktivní panel (nepohltí klik, jen ho zaznamená)
    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onPressedChanged: if (pressed) root.activate()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 0

        // Lišta tabů
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            Layout.topMargin: Tokens.padding.small
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.tabs.length

                StyledRect {
                    id: tab

                    required property int index
                    readonly property bool current: index === root.currentTab

                    Layout.fillWidth: true
                    Layout.maximumWidth: 220
                    implicitHeight: tabInner.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: current ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        color: tab.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        onClicked: mouse => mouse.button === Qt.MiddleButton ? root.closeTab(tab.index) : root.selectTab(tab.index)
                    }

                    // přetažení souboru na tab = přepnout na něj
                    DropArea {
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onEntered: root.selectTab(tab.index)
                    }

                    RowLayout {
                        id: tabInner

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.large
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: root.tabCwd(tab.index).length === 1 && root.tabCwd(tab.index)[0] === "Home" ? "home" : "folder"
                            color: tab.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fill: tab.current ? 1 : 0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.tabName(tab.index)
                            elide: Text.ElideRight
                            color: tab.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                        }

                        Item {
                            // místo zůstává i u jediného tabu, aby obě lišty měly stejnou výšku
                            opacity: root.tabs.length > 1 ? 1 : 0
                            enabled: root.tabs.length > 1
                            implicitWidth: closeIcon.implicitHeight + Tokens.padding.extraSmall
                            implicitHeight: implicitWidth

                            StateLayer {
                                radius: Tokens.rounding.full
                                onClicked: root.closeTab(tab.index)
                            }

                            MaterialIcon {
                                id: closeIcon

                                anchors.centerIn: parent
                                text: "close"
                                color: tab.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }

            Item {
                implicitWidth: addTabIcon.implicitHeight + Tokens.padding.small * 2
                implicitHeight: implicitWidth

                StateLayer {
                    radius: Tokens.rounding.full
                    onClicked: root.newTab()
                }

                MaterialIcon {
                    id: addTabIcon

                    anchors.centerIn: parent
                    text: "add"
                    color: Colours.palette.m3primary
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        HeaderBar {
            Layout.fillWidth: true
            dialog: root
        }

        FolderContents {
            id: folderContents

            Layout.fillWidth: true
            Layout.fillHeight: true
            dialog: root
        }
    }
}
