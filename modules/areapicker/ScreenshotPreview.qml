pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

// Náhled hotového screenshotu v rohu obrazovky (jako ve Spectacle):
// obrázek se uloží a zkopíruje, náhled jde přetáhnout do jiné aplikace, klik ho otevře v editoru.
Scope {
    id: root

    property string path: ""
    property ShellScreen targetScreen: null
    property bool dragging: false

    function show(tmpPath: string, screen: ShellScreen): void {
        const name = Qt.formatDateTime(new Date(), "'Screenshot_'yyyyMMdd_HHmmss'.png'");

        targetScreen = screen;
        store.pendingPath = `${Paths.pictures}/Screenshots/${name}`;
        store.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && mv \"$1\" \"$2\" && wl-copy --type image/png < \"$2\"", "sh", tmpPath, store.pendingPath];
        store.running = true;
    }

    function hide(): void {
        path = "";
    }

    Process {
        id: store

        property string pendingPath

        onExited: exitCode => {
            if (exitCode === 0) {
                root.path = store.pendingPath;
            } else {
                Quickshell.execDetached(["notify-send", "-a", "caelestia-cli", "-u", "critical", "Screenshot", "Failed to save screenshot"]);
            }
        }
    }

    Timer {
        interval: 10000
        running: root.path !== "" && !root.dragging && !cardHover.hovered
        onTriggered: root.hide()
    }

    HoverTracker {
        id: cardHover
    }

    LazyLoader {
        active: root.path !== "" && root.targetScreen !== null

        StyledWindow {
            id: win

            screen: root.targetScreen
            name: "screenshot-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.bottom: true
            anchors.right: true
            margins.bottom: 24
            margins.right: 24
            implicitWidth: 340
            implicitHeight: 230

            StyledRect {
                id: card

                anchors.fill: parent
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainer
                border.width: 1
                border.color: Colours.palette.m3outlineVariant

                Image {
                    id: thumbnail

                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.bottomMargin: 34
                    source: `file://${encodeURI(root.path)}`
                    sourceSize.width: 640
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }

                StyledText {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Drag to an app · click to edit"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                Item {
                    id: dragProxy

                    width: thumbnail.width
                    height: thumbnail.height
                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.proposedAction: Qt.CopyAction
                    Drag.mimeData: ({ "text/uri-list": `file://${encodeURI(root.path)}\r\n` })
                    Drag.onDragStarted: root.dragging = true
                    Drag.onDragFinished: {
                        root.dragging = false;
                        dragProxy.x = 0;
                        dragProxy.y = 0;
                    }
                }

                MouseArea {
                    id: dragArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: dragProxy
                    drag.threshold: 8
                    onContainsMouseChanged: cardHover.hovered = containsMouse
                    onPressed: mouse => {
                        dragProxy.Drag.hotSpot.x = 80;
                        dragProxy.Drag.hotSpot.y = 50;
                        thumbnail.grabToImage(result => dragProxy.Drag.imageSource = result.url, Qt.size(160, 100));
                    }
                    onClicked: {
                        Quickshell.execDetached(["swappy", "-f", root.path]);
                        root.hide();
                    }
                }

                StyledRect {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Tokens.rounding.full
                    color: Qt.alpha(Colours.palette.m3surface, 0.85)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        color: Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.hide()
                    }
                }
            }
        }
    }

    component HoverTracker: QtObject {
        property bool hovered: false
    }
}
