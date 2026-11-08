import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// alt-tab, the overlay: hold the mod, tap tab, let go — the highlighted window lands. a strip of cards dead center:
// icon, title, workspace dot, minimized ones dimmed. the order is most-recently-focused (kept here, hypr doesn't hand
// it out); never-focused windows trail behind. commit is a timer: 700 ms after the last tab tap the selection lands,
// so tap-tap-tap-release feels like windows', and alt+tab and super+tab drive the same thing
PanelWindow {
    id: root

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
    property int sel: 0

    // addresses, most recent first; the rest of the windows trail in creation order
    property var order: []
    readonly property var wins: order.map(a => Hyprland.toplevels.values.find(t => t.address === a))
        .filter(t => t).concat(Hyprland.toplevels.values.filter(t => !order.includes(t.address)))
    readonly property int n: wins.length

    function icon(cls) {
        return Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon || "application-x-executable", "application-x-executable");
    }
    function wsOf(t) {
        return Hyprland.workspaces.values.find(w => w.toplevels.values.includes(t))?.id ?? 0;
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (!t) return;
            root.order = [t.address].concat(root.order.filter(a => a !== t.address));
        }
    }

    Timer { id: commit; interval: 700; onTriggered: root.land() }
    function step(d) {
        commit.restart();
        if (!shown) { shown = true; sel = 0; }
        if (!n) return;
        sel = (sel + d + n) % n;
    }
    function arm() { commit.restart(); } // the mod came up — land whatever is highlighted
    function cancel() { commit.stop(); shown = false; sel = 0; }
    function land() {
        const w = wins[sel];
        shown = false;
        sel = 0;
        // activate, not dispatch: a minimized window comes back instead of just getting focus
        if (w) w.wayland.activate();
    }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-switch"

    Stage {
        MouseArea { anchors.fill: parent; onClicked: root.cancel() } // a stray click means no

        Rectangle {
            id: strip
            y: (parent.height - height) / 2
            x: (parent.width - width) / 2
            width: kids.width + 24
            height: 92
            opacity: root.t
            radius: Skin.corner(46)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }

            Row {
                id: kids
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: root.shown ? root.wins : []

                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool on: index === root.sel
                        readonly property string cls: modelData.lastIpcObject?.class ?? modelData.wayland.appId ?? ""
                        readonly property bool min: modelData.wayland.minimized
                        width: 200
                        height: 68
                        radius: Skin.corner(34)
                        color: on ? Skin.fg : min ? Skin.s1 : Skin.s2
                        border { width: 1; color: on ? Skin.fg : Skin.s3 }
                        opacity: root.t
                        Behavior on color { ColorAnimation { duration: Skin.t } }

                        Image {
                            id: pic
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            source: root.icon(card.cls)
                            sourceSize: Qt.size(width, height)
                            mipmap: true
                            visible: status === Image.Ready
                            layer.enabled: Skin.light
                            layer.effect: MultiEffect { brightness: -1 }
                        }
                        Column {
                            x: pic.visible ? 54 : 20
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (pic.visible ? 68 : 36)
                            spacing: 3
                            Lb {
                                width: parent.width
                                elide: Text.ElideRight
                                text: card.cls.split(".").pop() || "app"
                                color: card.on ? Skin.ink : card.min ? Skin.mute : Skin.grey
                                px: 10
                            }
                            // the title in the ui font — labels are caps, a window title is not
                            Text {
                                textFormat: Text.PlainText
                                width: parent.width
                                elide: Text.ElideRight
                                text: card.modelData.title
                                font { family: Skin.ui; pixelSize: 13 }
                                color: card.on ? Skin.ink : Skin.fg
                            }
                        }
                        // the workspace it lives on: a dot, the number inside
                        Rectangle {
                            x: parent.width - 22
                            y: 8
                            width: 14
                            height: 14
                            radius: 7
                            color: "transparent"
                            border { width: 1; color: card.on ? Skin.ink : Skin.s3 }
                            Lb { anchors.centerIn: parent; text: String(root.wsOf(card.modelData)); color: card.on ? Skin.ink : Skin.grey; px: 8 }
                        }
                        Lb {
                            visible: card.min
                            x: parent.width - 40
                            y: parent.height - 22
                            text: "min"
                            color: card.on ? Skin.mute : Skin.mute
                            px: 9
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.sel = index; root.land(); }
                        }
                    }
                }
                Lb { visible: !root.n; anchors.verticalCenter: parent.verticalCenter; x: 20; text: "no windows"; color: Skin.mute; px: 13 }
            }
        }
    }
}
