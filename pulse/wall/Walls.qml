import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// wallpapers: Super+Shift+W or settings → look. not a grid of thumbnails — the whole screen is the preview: the
// picked one assembles as dots in a wave from the strip below. the strip is dot-matrix thumbnail circles, the
// picked one centered in a ring (it lights up by how far through the collection you are), a red dot under the one
// live right now. the first circle is nothing: no image, just the grid and the orb.
// ←→ / wheel browse, tab — look (dots / mono / color), ↑↓ dot pitch, shift ↑↓ brightness, ↵ or a click on the
// picked one sets it, esc puts things back as they were. images come from Skin.state.wallDir, screen-sized copies
// go to Skin.wallCache (once)
PanelWindow {
    id: root

    readonly property string dir: Skin.state.wallDir || Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property var looks: ["dots", "mono", "color"]
    // copies are in the screen's physical pixels, with room to spare for cropping
    readonly property string res: {
        const s = Quickshell.screens[0];
        return s ? `${Math.round(s.width * s.devicePixelRatio)}x${Math.round(s.height * s.devicePixelRatio)}^` : "2880x1800^";
    }

    property var files: [] // originals that already have a copy, by name
    property var fresh: [] // what the current pass found
    readonly property var list: [""].concat(files)
    // the picked one is tracked by path and the index derives from it: while the cache is still filling, new
    // files land in the middle and the strip doesn't jump
    property string pick: ""
    readonly property int sel: Math.max(0, list.indexOf(pick))
    property int look: 0
    property int pitch: 10
    property int bright: 85

    function name(p) { return p ? p.slice(p.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "") : "nothing"; }
    function go(d) { pick = list[Math.max(0, Math.min(list.length - 1, sel + d))]; }

    // the preview only when browsing stops: each image is a decode plus 20 MB of vram — chase it and it stutters.
    // the strip moves right away
    property string view: ""
    onPickChanged: settle.restart()
    Timer { id: settle; interval: 160; onTriggered: root.view = root.pick }

    // the strip moves on one animation: pos chases sel and the circles place themselves from the fractional distance to it
    property real pos: sel
    Behavior on pos { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
    // circle at distance d: picked 190, neighbours 128, shrinking by 12, floor 64; fractional distances interpolate
    function size(d) { d = Math.abs(d); return d < 1 ? 190 - 62 * d : Math.max(64, 128 - (d - 1) * 12); }
    // circle centers at whole distances; past 9 nobody sees them anyway
    readonly property var at: {
        const a = [0];
        for (let k = 1; k <= 10; k++) a.push(a[k - 1] + (size(k - 1) + size(k)) / 2 + (k === 1 ? 44 : 22));
        return a;
    }
    function off(d) {
        const a = Math.min(Math.abs(d), 9), k = Math.floor(a), x = at[k] + (at[k + 1] - at[k]) * (a - k);
        return d < 0 ? -x : x;
    }

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
    Binding { target: Sys; property: "wallOpen"; value: root.visible }

    // multiple screens — wallpaper on all of them (shared; per-screen overrides get dropped) or just this one, the one the picker is on
    property string mon: ""
    property bool own: false
    function open() {
        const s = Skin.state;
        mon = Hyprland.focusedMonitor?.name ?? "";
        // "" counts as its own "no wallpaper". down to one screen (the other unplugged) — no toggle, wallpaper goes
        // shared, and picking "all" clears any per-screen override
        own = Quickshell.screens.length > 1 && Skin.own(mon)?.wall !== undefined;
        pick = Skin.scr(mon, "wall");
        view = pick;
        look = s.wallLook;
        pitch = s.wallPitch;
        bright = s.wallBright;
        if (!scan.running) {
            fresh = [];
            scan.running = true;
        }
        shown = true;
        stage.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function apply() {
        const s = Skin.state;
        if (own) Skin.setScr(mon, "wall", pick);
        else {
            s.wall = pick;
            for (const n in s.screens) if (s.screens[n].wall !== undefined) Skin.setScr(n, "wall", undefined);
        }
        s.wallLook = look;
        s.wallPitch = pitch;
        s.wallBright = bright;
        close();
    }

    // screen-sized copies. one bash pass checks freshness without a single process per file; missing or older than
    // the original — magick, three at a time (an 8k png eats hundreds of MB). each finished one comes back on
    // stdout. written to a temp file and moved: a magick cut short won't leave a broken copy newer than its original
    Process {
        id: scan
        command: ["bash", "-c", `shopt -s nullglob nocaseglob; mkdir -p "$2"; todo=()
for f in "$1"/*.{jpg,jpeg,png,webp}; do
    if [ "$2/\${f##*/}.jpg" -nt "$f" ]; then printf '%s\\n' "$f"; else todo+=("$f"); fi
done
[ \${#todo[@]} -eq 0 ] || printf '%s\\0' "\${todo[@]}" | xargs -0 -P 3 -I{} sh -c 'b=$(basename "$1")
magick "$1[0]" -resize "$3" -quality 90 "$2/.$b.jpg" 2>/dev/null && mv "$2/.$b.jpg" "$2/$b.jpg" && printf "%s\\n" "$1"' _ {} "$2" "$3"`,
            "bash", root.dir, Skin.wallCache, root.res]
        stdout: SplitParser {
            onRead: f => {
                root.fresh.push(f);
                if (!root.files.includes(f)) root.files = root.files.concat([f]).sort();
            }
        }
        // files gone from the folder — out; no changes — leave it alone: a new array would rebuild the whole strip
        onExited: {
            const f = root.fresh.slice().sort();
            if (f.join("\n") !== root.files.join("\n")) root.files = f;
        }
    }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-wall"

    Stage {
        id: stage
        opacity: root.t
        focus: true
        Keys.onPressed: e => {
            const up = e.key === Qt.Key_Up, down = e.key === Qt.Key_Down;
            if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.go(-1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) root.go(1);
            else if (e.key === Qt.Key_Home) root.pick = "";
            else if (e.key === Qt.Key_Tab) root.look = (root.look + 1) % 3;
            else if (e.key === Qt.Key_Backtab) root.look = (root.look + 2) % 3;
            else if ((up || down) && e.modifiers & Qt.ShiftModifier) root.bright = Math.max(10, Math.min(100, root.bright + (up ? 5 : -5)));
            else if (up || down) root.pitch = Math.max(4, Math.min(32, root.pitch + (up ? 1 : -1)));
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply();
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        // same backdrop as under home: grid and orb, visible on the nothing slide and in the wave toward it; once an image covers them, skip
        Rectangle { anchors.fill: parent; color: Skin.bg }
        Image {
            visible: Skin.state.grid && !prev.item?.opaque
            anchors.fill: parent
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#${Skin.hex(Skin.s2)}"/></svg>`)
        }
        Orb { visible: Skin.state.orb && !prev.item?.opaque; x: stage.width - 720; y: stage.height - 580 }
        // the preview lives while the picker is visible: close it and the two screen-sized images unload
        Loader {
            id: prev
            anchors.fill: parent
            active: root.visible
            sourceComponent: Wall {
                path: root.files.includes(root.view) ? Skin.wallSrc(root.view) : ""
                look: root.look
                pitch: root.pitch
                bright: root.bright / 100
                origin: Qt.point(width / 2, 850)
            }
        }

        // wheel browses; a click outside takes focus off the dials
        MouseArea {
            anchors.fill: parent
            property real acc: 0
            onClicked: stage.forceActiveFocus()
            onWheel: w => {
                acc += w.angleDelta.y || w.angleDelta.x;
                while (Math.abs(acc) >= 120) {
                    root.go(acc > 0 ? -1 : 1);
                    acc -= Math.sign(acc) * 120;
                }
            }
        }

        // labels have to stay readable over the image: the background fades in at the very top and bottom
        Rectangle {
            width: parent.width
            height: 380
            gradient: Gradient {
                GradientStop { position: 0; color: Skin.fade(Skin.bg, 0.85) }
                GradientStop { position: 1; color: Skin.fade(Skin.bg, 0) }
            }
        }
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: 460
            gradient: Gradient {
                GradientStop { position: 0; color: Skin.fade(Skin.bg, 0) }
                GradientStop { position: 1; color: Skin.fade(Skin.bg, 0.9) }
            }
        }

        // the doto index and the name
        Column {
            x: 150 - 30 * (1 - root.t)
            y: 110
            Lb { text: `wallpaper · ${root.files.length} in ${root.dir.replace(Quickshell.env("HOME"), "~")}` }
            Row {
                topPadding: 18
                spacing: 10
                Num { id: idx; text: String(root.sel).padStart(2, "0"); font.pixelSize: 150 }
                Num { anchors.baseline: idx.baseline; text: "/" + String(root.list.length - 1).padStart(2, "0"); font.pixelSize: 54; color: Skin.mute }
            }
            Lb { topPadding: 22; width: 700; elide: Text.ElideRight; text: root.name(root.pick); px: 14; color: Skin.fg }
        }

        // look and the dials
        Column {
            anchors { right: parent.right; rightMargin: 150 - 30 * (1 - root.t) }
            y: 110
            spacing: 30
            Pick { visible: Quickshell.screens.length > 1; anchors.right: parent.right; label: "for"; opts: ["all", root.mon.toLowerCase()]; cur: root.own ? 1 : 0; onPicked: i => root.own = i === 1 }
            Pick { label: "look"; opts: root.looks; cur: root.look; onPicked: i => root.look = i }
            Row {
                anchors.right: parent.right
                spacing: 36
                Dial { size: 120; label: "dot · px"; from: 4; to: 32; live: true; value: root.pitch; onMoved: v => root.pitch = v }
                Dial { size: 120; label: "light · %"; from: 10; to: 100; step: 5; live: true; value: root.bright; onMoved: v => root.bright = v }
            }
        }

        // the strip. the picked one is always centered — the ring stands still, circles ride beneath it. the circles
        // are one 190 size scaled down: the dot layer (Art) renders once; change width and all fifteen would redraw
        // every single frame
        Ring {
            x: stage.width / 2 - width / 2
            y: 850 - height / 2
            width: root.size(0) + 36
            height: width
            n: 60
            dot: 4
            f: root.list.length > 1 ? root.sel / (root.list.length - 1) : 0
        }
        Repeater {
            model: root.list
            Item {
                id: th
                required property string modelData
                required property int index
                readonly property real d: index - root.pos
                visible: Math.abs(d) < 7.5
                x: stage.width / 2 + root.off(d) - 95
                y: 850 - 95
                width: 190
                height: 190
                scale: root.size(d) / 190
                opacity: 1 - Math.abs(d) * 0.12

                Loader {
                    anchors.fill: parent
                    active: th.visible && !!th.modelData
                    sourceComponent: Art { url: "file://" + Skin.wallSrc(th.modelData).split("/").map(encodeURIComponent).join("/"); step: 6 }
                }
                Rectangle {
                    visible: !th.modelData
                    anchors.fill: parent
                    radius: width / 2
                    color: Skin.bg
                    border { width: 1; color: Skin.s3 }
                    Lb { anchors.centerIn: parent; text: "nothing" }
                }
                // live right now
                Rectangle {
                    visible: th.modelData === Skin.scr(root.mon, "wall")
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: th.index === root.sel ? 36 : 22 }
                    width: 10
                    height: 10
                    radius: 5
                    color: Skin.accent
                }
                TapHandler {
                    onTapped: {
                        if (th.index === root.sel) root.apply();
                        else root.pick = th.modelData;
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 }
            spacing: 34
            Lb { text: "←→ browse" }
            Lb { text: "tab look" }
            Lb { text: "↑↓ dot size" }
            Lb { text: "shift ↑↓ light" }
            Lb { text: "↵ set" }
            Lb { text: "esc back"; TapHandler { onTapped: root.close() } }
        }
    }
}
