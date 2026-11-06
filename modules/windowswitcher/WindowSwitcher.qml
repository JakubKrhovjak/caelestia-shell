pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.misc
import qs.services
import qs.utils

// Přepínač oken na Alt + Tab: karusel s živými náhledy uprostřed obrazovky.
// Pořadí je podle naposledy použitých oken, po puštění Alt se vybrané okno zvedne dopředu.
Scope {
    id: root

    property bool open: false
    property bool loading: false
    property bool pendingCommit: false
    property int pendingSteps: 0
    property int track: 0
    property var windows: []
    property ShellScreen targetScreen: null

    // Prostředí desk: jen okna z monitoru s fokusem a bez vyskakovacích oken z tray
    property bool focusedMonitorOnly: false
    property var ignoredClasses: []
    property string minimizedWorkspace: "" // skrytá plocha s minimalizovanými okny; výběrem se okno vrátí

    readonly property int count: windows.length
    readonly property int selectedIndex: count > 0 ? ((track % count) + count) % count : 0
    readonly property var selectedWindow: windows[selectedIndex] ?? null

    function start(steps: int): void {
        if (open) {
            step(steps);
        } else if (loading) {
            pendingSteps += steps;
        } else {
            loading = true;
            pendingCommit = false;
            pendingSteps = steps;
            clients.running = true;
        }
    }

    function step(steps: int): void {
        // Do tří oken se karusel netočí dokola, jen se posouvá po přímce
        track = count < 4 ? ((track + steps) % count + count) % count : track + steps;
    }

    function onClients(json: string): void {
        const list = JSON.parse(json)
            .filter(c => c.mapped && !c.hidden && (c.workspace.id > 0 || (minimizedWorkspace !== "" && c.workspace.name === minimizedWorkspace)))
            .filter(c => !focusedMonitorOnly || c.monitor === Hypr.focusedMonitor?.id)
            .filter(c => !ignoredClasses.includes(c.class))
            .sort((a, b) => a.focusHistoryID - b.focusHistoryID);

        loading = false;
        if (list.length < 2)
            return;

        windows = list;
        track = 0;
        step(pendingSteps);
        targetScreen = Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0];

        if (pendingCommit)
            commit();
        else
            open = true;
    }

    function commit(): void {
        if (loading) {
            pendingCommit = true;
            return;
        }
        if (!selectedWindow)
            return;

        activate(selectedWindow);
        close();
    }

    function close(): void {
        open = false;
        windows = [];
    }

    function overlaps(a: var, b: var): bool {
        return a.at[0] < b.at[0] + b.size[0] && b.at[0] < a.at[0] + a.size[0]
            && a.at[1] < b.at[1] + b.size[1] && b.at[1] < a.at[1] + a.size[1];
    }

    function activate(win: var): void {
        // Rozložené okno nejde zvednout nad plovoucí, takže se samo přepne na plovoucí se stejnou geometrií
        const covered = !win.floating && windows.some(w => w.floating && w.workspace.id === win.workspace.id && overlaps(win, w));
        const target = `"address:${win.address}"`;
        const floatLines = covered ? [
            `hl.dispatch(hl.dsp.window.float({ action = "on", window = ${target} }))`,
            `hl.dispatch(hl.dsp.window.resize({ x = ${win.size[0]}, y = ${win.size[1]}, relative = false, window = ${target} }))`,
            `hl.dispatch(hl.dsp.window.move({ x = ${win.at[0]}, y = ${win.at[1]}, relative = false, window = ${target} }))`,
        ] : [];

        // Minimalizované okno vrací restore_window z desk/minimize.lua, fokus na skrytou plochu by ji celou otevřel
        const restoreLines = win.workspace.name === minimizedWorkspace && minimizedWorkspace !== "" ? [
            `restore_window("${win.address}", ${Hypr.focusedMonitor?.activeWorkspace?.id ?? 1})`,
        ] : [];

        Quickshell.execDetached(["hyprctl", "eval", [
            ...restoreLines,
            `hl.dispatch(hl.dsp.focus({ window = ${target} }))`,
            ...floatLines,
            "hl.dispatch(hl.dsp.window.bring_to_top())",
        ].join("; ")]);
    }

    Process {
        id: clients

        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.onClients(text)
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "windowSwitcherNext"
        description: "Window switcher: next window"
        onPressed: root.start(1)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "windowSwitcherPrev"
        description: "Window switcher: previous window"
        onPressed: root.start(-1)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "windowSwitcherCommit"
        description: "Window switcher: activate selected window"
        onPressed: root.commit()
    }

    IpcHandler {
        target: "windowswitcher"

        function cancel(): void {
            root.close();
        }

        function next(): void {
            root.start(1);
        }
    }

    LazyLoader {
        active: root.open

        StyledWindow {
            name: "windowswitcher"
            screen: root.targetScreen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Item {
                id: content

                readonly property real cardHeight: Math.round(height * 0.42)
                readonly property real cardWidth: Math.round(cardHeight * 1.6)
                property real position: root.track
                property real shown: 0

                anchors.fill: parent
                focus: true
                opacity: shown

                Component.onCompleted: shown = 1

                function distance(index: int): real {
                    if (root.count < 4)
                        return index - position;

                    const wrapped = ((index - position) % root.count + root.count) % root.count;
                    return wrapped > root.count / 2 ? wrapped - root.count : wrapped;
                }

                Behavior on position {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on shown {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        root.close();
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.commit();
                    else if (event.key === Qt.Key_Left)
                        root.step(-1);
                    else if (event.key === Qt.Key_Right)
                        root.step(1);
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt && !event.isAutoRepeat)
                        root.commit();
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                Repeater {
                    model: root.windows

                    Item {
                        id: card

                        required property var modelData
                        required property int index

                        readonly property real d: content.distance(index)
                        readonly property real absD: Math.abs(d)
                        readonly property bool selected: index === root.selectedIndex
                        readonly property real edgeFade: root.count < 4 ? 1 : Math.min(1, (root.count / 2 - absD) * 2)
                        readonly property real offset: Math.min(absD, 1) * content.cardWidth * 0.72 + Math.max(absD - 1, 0) * content.cardWidth * 0.4

                        width: content.cardWidth
                        height: content.cardHeight
                        x: (content.width - width) / 2 + Math.sign(d) * offset
                        y: (content.height - height) / 2
                        z: 100 - absD * 10
                        scale: Math.max(0.6, 1 - absD * 0.2)
                        opacity: Math.max(0, Math.min(1, 3 - absD)) * Math.max(0, edgeFade)
                        visible: opacity > 0

                        transform: Rotation {
                            origin.x: card.width / 2
                            origin.y: card.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: Math.max(-1, Math.min(1, card.d)) * -36
                        }

                        StyledClippingRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3surfaceContainer

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: parent.height * 0.3
                                visible: !preview.hasContent
                                source: Icons.getAppIcon(card.modelData.class, "image-missing")
                            }

                            ScreencopyView {
                                id: preview

                                anchors.centerIn: parent
                                captureSource: Hypr.toplevels.values.find(t => `0x${t.address.replace(/^0x/, "")}` === card.modelData.address)?.wayland ?? null // qmllint disable unresolved-type
                                live: card.absD < 1.5
                                constraintSize.width: card.width
                                constraintSize.height: card.height
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "#000000"
                                opacity: Math.min(0.5, card.absD * 0.35)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.rounding.medium
                            color: "transparent"
                            border.width: 3
                            border.color: Colours.palette.m3primary
                            opacity: Math.max(0, 1 - card.absD * 2)
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.step(card.index - root.selectedIndex);
                                root.commit();
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (parent.height + content.cardHeight) / 2 + Tokens.padding.extraLargeIncreased
                    spacing: Tokens.spacing.medium
                    z: 200

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 32
                        source: Icons.getAppIcon(root.selectedWindow?.class ?? "", "image-missing")
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, content.width * 0.5)
                        text: root.selectedWindow?.title ?? ""
                        color: "#ffffff"
                        elide: Text.ElideRight
                        font: Tokens.font.body.large
                    }
                }
            }
        }
    }
}
