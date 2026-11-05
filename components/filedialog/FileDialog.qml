pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.I18n
import qs.components
import qs.services

LazyLoader {
    id: loader

    property list<string> cwd: ["Home"]
    property string filterLabel: Tr.tr("All files")
    property list<string> filters: ["*"]
    property string title: Tr.tr("Select a file")

    signal accepted(path: string)
    signal rejected

    function open(): void {
        activeAsync = true;
    }

    function close(): void {
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
            loader.accepted(path);
        }

        function rejected(): void {
            loader.rejected();
        }

        function switchPane(): void {
            (activePane === leftPane ? rightPane : leftPane).activate();
        }

        implicitWidth: 1400
        implicitHeight: 700
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
                Layout.fillHeight: true
                dialog: root.activePane
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
