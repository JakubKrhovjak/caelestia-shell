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
