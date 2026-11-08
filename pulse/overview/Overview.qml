import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// overview: every workspace and its windows on one scrim, super+ctrl+up. type to filter, click a tile to land on
// it, the x in the corner closes a window. tiles are icon cards — hypr doesn't give thumbnails out. the keyboard is
// exclusive here, so like the launcher i focus through a timer on release: hypr would take the focus back the moment
// the overlay folds
PanelWindow {
    id: root

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }

    readonly property string q: input.text.trim().toLowerCase()
    readonly property var spaces: Hyprland.workspaces.values.filter(w => w.id >= 1).sort((a, b) => a.id - b.id)
    // [{ id, wins }] — a workspace with no matches disappears; an empty query keeps every occupied one
    readonly property var groups: spaces.map(w => ({
        id: w.id,
        wins: w.toplevels.values.filter(t => {
            if (!q) return true;
            const cls = t.lastIpcObject?.class ?? "";
            return (t.title + " " + cls).toLowerCase().includes(q);
        })
    })).filter(g => g.wins.length)

    function icon(cls) {
        return Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon || "application-x-executable", "application-x-executable");
    }
    // the keyboard is mine (exclusive) — hypr would hand focus straight back on release. land on the next frame
    Timer {
        id: focusT
        property string addr
        interval: 100
        onTriggered: Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${addr}" })`)
    }
    function focus(addr) {
        root.shown = false;
        focusT.addr = addr;
        focusT.restart();
    }
    function open() { shown = true; input.text = ""; input.forceActiveFocus(); }
    function toggle() { shown ? root.shown = false : open(); }

    onVisibleChanged: if (visible) input.forceActiveFocus()

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-overview"

    Rectangle {
        anchors.fill: parent
        color: Skin.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.shown = false }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: 120 + 24 * (1 - root.t)
            width: 1040
            height: Math.min(stage.height - 240, 30 + 60 + 18 + body.contentHeight + 30)
            opacity: root.t
            radius: Skin.corner(44)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
            MouseArea { anchors.fill: parent } // keep clicks inside from hitting the scrim

            // head: the word, the filter, the hint
            Row {
                x: 34
                y: 26
                width: parent.width - 68
                spacing: 20

                Num { text: "overview"; font.pixelSize: 30 }
                Rectangle {
                    id: search
                    width: parent.width - 204
                    height: 52
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Skin.corner(26)
                    color: Skin.s2

                    Icon { id: lens; x: 18; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Skin.grey; font.pixelSize: 20 }
                    TextInput {
                        id: input
                        anchors { left: lens.right; leftMargin: 14; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        font { family: Skin.ui; pixelSize: 20 }
                        color: Skin.fg
                        clip: true
                        cursorDelegate: Rectangle {
                            width: 2
                            color: Skin.accent
                            Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                        }
                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Escape) root.shown = false;
                        }
                        Text {
                            visible: !input.text
                            x: 6
                            text: "filter windows…"
                            font: input.font
                            color: Skin.mute
                        }
                    }
                }
                Lb { anchors.verticalCenter: parent.verticalCenter; text: "↵ nothing · esc out"; px: 10; opacity: 0.7 }
            }

            Flickable {
                id: body
                x: 34
                y: 104
                width: parent.width - 68
                height: panel.height - 134
                clip: true
                contentHeight: rows.height

                Column {
                    id: rows
                    width: parent.width
                    spacing: 26

                    Repeater {
                        model: root.groups

                        Column {
                            id: group
                            required property var modelData
                            width: parent.width
                            spacing: 12

                            Row {
                                spacing: 12
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: Skin.fg
                                    Lb { anchors.centerIn: parent; text: String(group.modelData.id); color: Skin.ink; px: 12 }
                                }
                                Lb { anchors.verticalCenter: parent.verticalCenter; text: group.wins.length + (group.wins.length === 1 ? " window" : " windows"); px: 10 }
                            }

                            Flow {
                                width: parent.width
                                spacing: 14

                                Repeater {
                                    model: group.modelData.wins

                                    Rectangle {
                                        id: tile
                                        required property var modelData
                                        readonly property string cls: modelData.lastIpcObject?.class ?? modelData.wayland.appId ?? ""
                                        readonly property bool min: modelData.wayland.minimized
                                        readonly property bool act: modelData.activated
                                        width: 236
                                        height: 84
                                        radius: Skin.corner(28)
                                        color: act ? Skin.s3 : hover.hovered ? Skin.s2 : Skin.s1
                                        border { width: 1; color: act ? Skin.fg : Skin.s2 }
                                        Behavior on color { ColorAnimation { duration: Skin.t } }

                                        Image {
                                            id: pic
                                            x: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 30
                                            height: 30
                                            source: root.icon(tile.cls)
                                            sourceSize: Qt.size(width, height)
                                            mipmap: true
                                            visible: status === Image.Ready
                                            layer.enabled: Skin.light
                                            layer.effect: MultiEffect { brightness: -1 }
                                            opacity: tile.min ? 0.4 : 1
                                        }
                                        Column {
                                            x: pic.visible ? 58 : 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - (pic.visible ? 92 : 52)
                                            spacing: 3
                                            Text {
                                                textFormat: Text.PlainText
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: tile.modelData.title || tile.cls
                                                font { family: Skin.ui; pixelSize: 14 }
                                                color: Skin.fg
                                                opacity: tile.min ? 0.55 : 1
                                            }
                                            Lb { width: parent.width; elide: Text.ElideRight; text: tile.cls.split(".").pop() || (tile.min ? "minimized" : "app"); px: 10 }
                                        }
                                        // close: an x on hover, top right
                                        Rectangle {
                                            x: parent.width - 34
                                            y: 8
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: xh.hovered ? Skin.red : "transparent"
                                            Behavior on color { ColorAnimation { duration: Skin.t } }
                                            Lb { anchors.centerIn: parent; text: "×"; color: xh.hovered ? Skin.ink : Skin.grey; px: 14 }
                                            HoverHandler { id: xh; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: tile.modelData.wayland?.close() } // it may already be gone
                                        }
                                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: root.focus(tile.modelData.address) }
                                    }
                                }
                            }
                        }
                    }
                    Lb { visible: !root.groups.length; x: 6; text: root.q ? "nothing matches" : "no windows anywhere"; px: 13 }
                }
            }
        }
    }
}
