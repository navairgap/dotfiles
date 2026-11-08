import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// snap zones, the eyes for the binds: super+alt+arrows snaps the active window to a half (up is the whole screen,
// down drops it centered), super+alt+1..4 to a quarter — hypr does the move, this flashes the zone under the window
// for a beat so the snap reads. the outline is the one live thing on screen, like everything here
PanelWindow {
    id: root

    property string region: ""
    property real t: region !== "" ? 1 : 0
    Behavior on t { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
    Timer { id: hold; interval: 280; onTriggered: root.region = "" }

    // fx, fy, fw, fh in % — mirrors fn.snap_active in hypr/hyprland/functions.lua, zone for zone
    readonly property var regions: ({
        left: [0, 0, 50, 100], right: [50, 0, 50, 100], top: [0, 0, 100, 50], bottom: [0, 50, 100, 50],
        max: [0, 0, 100, 100], center: [20, 20, 60, 60],
        tl: [0, 0, 50, 50], tr: [50, 0, 50, 50], bl: [0, 50, 50, 50], br: [50, 50, 50, 50]
    })
    readonly property var r: regions[region] ?? null
    readonly property var mon: Hyprland.focusedMonitor

    function flash(name) {
        region = name;
        hold.restart();
    }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-snap"

    Stage {
        Rectangle {
            // the overlay lands on the focused screen, the zones are fractions of that monitor — same thing
            visible: !!root.r && !!root.mon && root.t > 0
            // r and mon are guarded together — a binding touching r[0] with r null would throw on every tick
            readonly property var box: root.r && root.mon ? root.r : null
            x: box && root.mon ? root.mon.width * box[0] / 100 : 0
            y: box && root.mon ? root.mon.height * box[1] / 100 : 0
            width: box && root.mon ? root.mon.width * box[2] / 100 : 0
            height: box && root.mon ? root.mon.height * box[3] / 100 : 0
            opacity: root.t * 0.9
            radius: Skin.corner(24)
            color: "transparent"
            border { width: 3; color: Skin.accent }
            // a whisper of fill, all ink
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: parent.radius - 2
                color: Skin.fg
                opacity: 0.08
            }
        }
    }
}
