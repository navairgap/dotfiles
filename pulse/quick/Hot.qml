import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// hot edge: the cursor rests against the right edge and quick settings slide out (quick.peek). a 2px strip over the bottom 80%:
// misses the top corner and the scrollbars hugging the edge
PanelWindow {
    id: root

    signal triggered

    visible: Skin.state.quickHover
    anchors { right: true; bottom: true }
    implicitWidth: 2
    implicitHeight: Math.round(screen.height * 0.8)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pulse-hot"

    HoverHandler { id: hov; onHoveredChanged: hovered ? dwell.restart() : dwell.stop() }
    Timer { id: dwell; interval: 150; onTriggered: if (hov.hovered) root.triggered() }
}
