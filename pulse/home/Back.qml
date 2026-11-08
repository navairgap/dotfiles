import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// home's backdrop, its own window on the background layer: dot grid, halftone orb, wallpaper. home itself (clock,
// bento) is the transparent layer above, and it redraws constantly — colon, rings, spinning cover. the wallpaper
// is a fullscreen shader, so in one window it would run on every home frame. here a frame happens only on the
// wave, a look change or the orb breathing. an image covering everything — the grid and orb stop drawing, the orb
// stops breathing: the window sits still
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: Skin.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "pulse-back"

    readonly property bool home: (Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.length ?? 0) === 0 // own screen is empty
    property real phase: 0
    Timer { running: root.home && orb.visible; interval: 100; repeat: true; onTriggered: root.phase += 0.1 }

    Stage {
        id: stage
        Image {
            visible: Skin.state.grid && !wall.opaque
            anchors.fill: parent
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#${Skin.hex(Skin.s2)}"/></svg>`)
        }
        Orb { id: orb; visible: Skin.state.orb && !wall.opaque; x: stage.width - 720; y: stage.height - 580; phase: root.phase }
        Wall { id: wall; anchors.fill: parent; path: Skin.wallSrc(Skin.scr(root.screen?.name, "wall")); animate: !Sys.wallOpen }
    }
}
