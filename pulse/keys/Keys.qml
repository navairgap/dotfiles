import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// the cheat sheet: every bind on one card, ctrl+alt+k. hand-kept — keybinds.lua is the truth, this is the map
PanelWindow {
    id: root

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
    function toggle() { shown = !shown; }

    readonly property var groups: [
        { head: "windows", rows: [
            ["alt+tab / super+tab", "window switcher — hold, tap, release"],
            ["super+ctrl+up", "overview: every workspace"],
            ["super+alt+arrows", "snap: halves · up full · down centered"],
            ["super+alt+1..4", "snap: quarters"],
            ["super+f full · super+alt+f max · super+c close", ""],
            ["super+drag · super+right-drag", "move · resize"],
            ["super+1..0", "workspaces · shift sends the window"],
            ["super+s · super+m · super+d · super+r", "special: term · music · chat · todo"]
        ] },
        { head: "panels", rows: [
            ["super tap", "launcher — apps, style, windows, calc, files"],
            ["super+a", "quick settings · super+n the same"],
            ["super+space", "deck — the dashboard below"],
            ["super+i", "settings · super+shift+w wallpapers"],
            ["print · super+shift+s", "screenshot"],
            ["super+v clipboard · super+. emoji · super+p vpn", ""],
            ["super+esc · ctrl+alt+del", "power menu"],
            ["super+l", "lock"]
        ] },
        { head: "apps & system", rows: [
            ["super+q terminal · super+w browser", ""],
            ["super+e files · super+shift+k editor", ""],
            ["super+c close window · super+u kill", ""],
            ["super+shift+l suspend", ""],
            ["fn keys", "volume · mic · brightness"],
            ["ctrl+super+alt+r", "restart the shell — it also self-heals"]
        ] }
    ]

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-keys"

    Rectangle {
        anchors.fill: parent
        color: Skin.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.shown = false }
    }

    Stage {
        id: stage

        Rectangle {
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 + 24 * (1 - root.t)
            width: 760
            height: grid.height + 56
            opacity: root.t
            radius: Skin.corner(44)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
            MouseArea { anchors.fill: parent }

            Column {
                id: grid
                x: 36
                y: 30
                width: parent.width - 72
                spacing: 22

                Row {
                    width: parent.width
                    Num { text: "keys"; font.pixelSize: 30 }
                    Lb { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; text: "ctrl+alt+k · click out"; px: 10; opacity: 0.7 }
                }

                Repeater {
                    model: root.groups

                    Column {
                        id: grp
                        required property var modelData
                        width: grid.width
                        spacing: 4

                        Lb { text: grp.modelData.head; color: Skin.fg; px: 12 }
                        Repeater {
                            model: grp.modelData.rows

                            Item {
                                id: row
                                required property var modelData
                                width: grp.width
                                height: 34

                                Lb { anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.42; elide: Text.ElideRight; text: row.modelData[0]; color: Skin.fg; px: 12 }
                                Lb { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; width: parent.width * 0.55; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; visible: !!row.modelData[1]; text: row.modelData[1]; px: 11; opacity: 0.75 }
                                Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: Skin.s2; opacity: 0.5 }
                            }
                        }
                    }
                }
            }
        }
    }
}
