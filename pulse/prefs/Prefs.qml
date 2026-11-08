import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.settings
import Qt5Compat.GraphicalEffects
import "../edge/flash.js" as FlashShape

// pulse settings: Super+I. not a form — objects. on the left a column of Doto words like in the power menu — the picked one large,
// with a red dot. on the right the section live: home — a bento 3 × 3 mock-up, deck — a screen with a panel at its edge, windows —
// a desktop with gaps, idle — a minute scale the screen goes dark along. numbers are dot rings (drag round, wheel), toggles are
// pills the white slides out of. ↑↓ — sections, tab — across the objects, ←→ — change, esc — close.
// everything is live at once: Skin.state (pulse.json) and Rules.store (rules.json, shared with the sibling shell) + the matching apply.
// gaps/border/blur/shadows go through Skin.apply: Rules.windows() would hand the windows the sibling shell's look
PanelWindow {
    id: root

    property int sel: 0
    property string flashHover: "" // the edge-lights pattern under the cursor, else the applied one
    signal wallRequested // wallpaper has its own screen (wall/Walls), shell.qml opens it
    readonly property var sections: ["HOME", "DECK", "BAR", "LOOK", "EDGE LIGHTS", "STYLE", "WINDOWS", "DISPLAY", "AUDIO", "POWER", "INPUT", "IDLE", "SHELL"]
    readonly property string moves: "shift ←→ move · ↵ swap · del drop · drag"
    readonly property string rings: "drag round the rings · scroll"
    readonly property var hints: [moves, moves, moves, "", "hover a pattern — the strip plays it", "hover to preview · ↵ or click sets it", rings, "drag a screen to move it · " + rings, "click or ←→ a device", "↵ or click a mode", rings, "drag the marks", ""]
    readonly property var r: Rules.store

    // glyphs for the home widgets, the deck sections and the bar tray
    readonly property var icons: ({
        weather: "\u{F0595}", calendar: "\u{F00ED}", cpu: "\u{F061A}", ram: "\u{F035B}", gpu: "\u{F08AE}", disk: "\u{F02CA}",
        battery: "\u{F0079}", buds: "\u{F02CB}", player: "\u{F040A}", system: "\u{F0128}", cat: "\u{F011B}", cava: "\u{F0EA2}",
        clock: "\u{F0150}", perf: "\u{F04C5}", net: "\u{F05A9}", media: "\u{F075A}",
        layout: "\u{F030C}", wifi: "\u{F05A9}", bluetooth: "\u{F00AF}", sound: "\u{F057E}", notes: "\u{F009A}",
        mode: "\u{F04C5}", power: "\u{F0425}"
    })
    // round home widgets, the rest are 40 squares. loose end: ram/gpu/disk/battery are a guess (rings); once Home decides, i'll fix it
    readonly property var rounds: ["weather", "cpu", "ram", "gpu", "disk", "battery", "buds", "cava"]

    // ---- opening: it animates itself (the pulse layers run no_anim in hypr). the section is remembered between opens ----
    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
    function open() {
        pickMon = Hyprland.focusedMonitor?.name ?? "";
        shown = true;
        stage.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function go(i) {
        sel = (i + sections.length) % sections.length;
        stage.forceActiveFocus(); // focus would get lost in a hidden section
    }

    // the screen DISPLAY and HOME set up: on open — the one with focus; it got unplugged — the first
    property string pickMon
    readonly property var names: Quickshell.screens.map(s => s.name)
    readonly property string mon: names.includes(pickMon) ? pickMon : names[0] ?? ""
    readonly property bool multi: names.length > 1
    onMonChanged: home.cur = 0 // another screen has its own set — the old cursor points nowhere

    // ---- the id lists in Skin.state: home widgets, deck sections, the bar tray. i edit a copy — the JsonAdapter writes the file on assignment.
    // all of these return the new cursor. the widgets belong to screen mon: several screens — an edit gives that one its own set, until then they share ----
    function list(key) { return key === "widgets" ? Skin.scr(mon, "widgets") : Skin.state[key]; }
    function edit(key, f) {
        const a = list(key).slice();
        f(a);
        if (key === "widgets" && (multi || Skin.own(mon)?.widgets)) Skin.setScr(mon, "widgets", a);
        else Skin.state[key] = a;
    }
    function move(key, i, to) {
        if (to < 0 || to >= list(key).length || to === i) return i;
        edit(key, a => a.splice(to, 0, a.splice(i, 1)[0]));
        return to;
    }
    function cut(key, i) {
        const n = list(key).length;
        if (i >= n) return i;
        edit(key, a => a.splice(i, 1));
        return Math.max(0, Math.min(i, n - 2));
    }
    // ↵ on the picked one: the next of all that isn't in yet. an empty list — the first free
    function cycle(key, i, all) {
        const a = list(key);
        if (all.every(k => a.includes(k))) return i;
        i = Math.min(i, a.length);
        let j = all.indexOf(a[i]);
        do j = (j + 1) % all.length; while (a.includes(all[j]));
        edit(key, b => b[i] = all[j]);
        return i;
    }
    // the tray: already there — take out, not — insert after the cursor
    function flip(key, w, cur) {
        const a = list(key), i = a.indexOf(w);
        if (i >= 0) {
            edit(key, b => b.splice(i, 1));
            return Math.max(0, Math.min(i < cur ? cur - 1 : cur, a.length - 2));
        }
        const at = Math.min(cur + 1, a.length);
        edit(key, b => b.splice(at, 0, w));
        return at;
    }
    // keys for a focused list: ←→ pick, shift ←→ reorder, ↵/space — next kind, del — take out. -1 — not my key
    function nav(e, key, cur, all) {
        const n = list(key).length, d = e.key === Qt.Key_Left ? -1 : e.key === Qt.Key_Right ? 1 : 0;
        if (d && (e.modifiers & Qt.ShiftModifier)) return move(key, cur, cur + d);
        if (d) return n ? (cur + d + n) % n : 0;
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) return cycle(key, cur, all);
        if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) return cut(key, cur);
        return -1;
    }
    // bento packing, same as at home (and grid-auto-flow in the concept): left to right, top down; didn't fit the row — the next one,
    // the hole stays; three rows, past that — off grid
    function pack(ids) {
        let row = 0, col = 0;
        return ids.map((w, i) => {
            const span = Skin.kinds[w] ?? 1;
            if (col + span > 3) {
                row++;
                col = 0;
            }
            const c = { id: w, i, row, col, span, fits: row < 3 };
            col += span;
            return c;
        });
    }

    SystemClock { id: clock; enabled: root.visible; precision: SystemClock.Minutes }
    readonly property string hello: { const h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"; }
    readonly property string who: (Skin.state.name || Quickshell.env("USER")).replace(/&/g, "&amp;").replace(/</g, "&lt;")

    // the name and tagline of the running shell — from its rice.json (the same one the Rice app draws from)
    property var meta: ({})
    FileView { path: Quickshell.shellPath("rice.json"); onLoaded: try { root.meta = JSON.parse(text()); } catch (e) {} }
    // "switch shell" only when there's something to pick: other shells, sibling folders with a rice.json
    property int shells: 1
    Process {
        running: root.visible
        command: [Quickshell.env("HOME") + "/.config/quickshell/rice/rice", "list"]
        stdout: StdioCollector { onStreamFinished: root.shells = text.trim().split("\n").length }
    }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    // several screens — on demand: a click into a window on another monitor takes the keyboard, a click here gives it back. one screen —
    // Exclusive: otherwise a new window would grab the keyboard under the solid backdrop and arrows and esc would vanish into nothing
    WlrLayershell.keyboardFocus: shown ? multi ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-prefs"

    Rectangle {
        anchors.fill: parent
        color: Skin.bg // solid: at 5% the bright bits of windows behind showed through
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: stage.forceActiveFocus() } // a miss just drops focus; esc does the closing
    }

    Stage {
        id: stage
        opacity: root.t
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Up || e.key === Qt.Key_K) root.go(root.sel - 1);
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J) root.go(root.sel + 1);
            else if (e.key === Qt.Key_Right && stage.activeFocus) stage.nextItemInFocusChain(true)?.forceActiveFocus();
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        // sections: the picked one large with a red dot (while the name is being typed, red is the caret and the dot goes white)
        Column {
            x: 150 - 30 * (1 - root.t)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 22
            Repeater {
                model: root.sections
                Row {
                    id: word
                    required property string modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    spacing: 26
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: word.on
                        width: 26
                        height: 26
                        radius: 13
                        color: name.activeFocus ? Skin.fg : Skin.accent
                    }
                    Num {
                        text: word.modelData
                        font.pixelSize: word.on ? 112 : 46
                        color: word.on ? Skin.fg : Skin.mute
                        Behavior on font.pixelSize { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                        Behavior on color { ColorAnimation { duration: Skin.t } }
                    }
                    TapHandler { onTapped: root.go(word.index) }
                }
            }
        }

        Row {
            x: 150
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: "↑↓ section" }
            Lb { text: "tab · ←→ change" }
            Lb { visible: !!text; text: root.hints[root.sel] }
            Lb { text: "esc close"; TapHandler { onTapped: root.close() } }
        }

        // ---- HOME: home at 168/220 — the same widgets, order and packing. click — pick, another click or ↵ — the next kind,
        // drag — it takes the spot of whatever it was dropped on. what didn't fit 3 × 3 — a pale outline on the right.
        // several screens — a picker on top: each has its own set ----
        Page {
            id: home
            k: 0
            caption: `home${root.multi ? ` · ${root.mon.toLowerCase()}${Skin.scr(root.mon, "home") ? "" : " · hidden there, display shows it"}` : ""}`
                + ` · bento 3 × 3 · ${used} of 9 cells`
            readonly property var cells: root.pack(root.list("widgets"))
            readonly property var placed: cells.filter(c => c.fits)
            readonly property var off: cells.filter(c => !c.fits)
            readonly property int used: placed.reduce((a, c) => a + c.span, 0)
            readonly property var cur_: cells[cur] ?? null
            property int cur: 0

            function tap(i) {
                grid.forceActiveFocus();
                cur = cur === i ? root.cycle("widgets", i, Object.keys(Skin.kinds)) : i;
            }
            // dropped at grid point p: onto a widget — its spot, into an empty cell — after the last one before it; off the grid — nothing
            function land(i, p) {
                if (p.x < 0 || p.y < 0 || p.x > grid.width || p.y > grid.height) return;
                const at = Math.min(2, Math.floor(p.y / 184)) * 3 + Math.min(2, Math.floor(p.x / 184));
                const hit = placed.find(c => c.row * 3 + c.col <= at && at < c.row * 3 + c.col + c.span);
                const n = placed.filter(c => c.row * 3 + c.col < at).length; // the placed are always the head of the list
                cur = root.move("widgets", i, hit ? hit.i : i < n ? n - 1 : n);
            }

            Pick { visible: root.multi; label: "screen"; opts: root.names.map(n => n.toLowerCase()); cur: root.names.indexOf(root.mon); onPicked: i => root.pickMon = root.names[i] }

            Row {
                spacing: 60

                Item {
                    id: grid
                    width: 536
                    height: 536
                    activeFocusOnTab: true
                    Keys.onPressed: e => {
                        const c = root.nav(e, "widgets", home.cur, Object.keys(Skin.kinds));
                        if (c < 0) return;
                        home.cur = c;
                        e.accepted = true;
                    }
                    Repeater {
                        model: 9
                        Dots {
                            required property int index
                            x: index % 3 * 184
                            y: Math.floor(index / 3) * 184
                        }
                    }
                    Repeater {
                        model: home.placed
                        Tile {
                            x: modelData.col * 184
                            y: modelData.row * 184
                        }
                    }
                }

                Column {
                    width: 404
                    spacing: 12
                    Lb { text: "cells" }
                    Row {
                        spacing: 10
                        Num { id: usedN; text: home.used; font.pixelSize: 150 }
                        Num { anchors.baseline: usedN.baseline; text: "/9"; font.pixelSize: 54; color: Skin.mute }
                    }
                    Lb {
                        width: parent.width
                        elide: Text.ElideRight
                        text: !home.cur_ ? "empty · ↵ adds one" : `${home.cur_.id} · ${home.cur_.span} cell${home.cur_.span > 1 ? "s" : ""}${home.cur_.fits ? "" : " · off grid"}`
                    }
                    // the cat gif (services/Gifs) — while the cat is picked. click, or ←→ when focused
                    Column {
                        id: gifPick
                        visible: home.cur_?.id === "cat"
                        topPadding: 28
                        spacing: 12
                        Lb {
                            width: 404
                            elide: Text.ElideRight
                            text: `gif · ${Gifs.name(Gifs.cur)} · ${Gifs.sel + 1} of ${Gifs.list.length}`
                            color: gifStrip.activeFocus ? Skin.fg : Skin.grey
                        }
                        ListView {
                            id: gifStrip
                            width: 404
                            height: 58
                            orientation: ListView.Horizontal
                            spacing: (width - 6 * 58) / 5 // exactly six to a row
                            clip: true
                            snapMode: ListView.SnapToItem
                            boundsBehavior: Flickable.StopAtBounds
                            keyNavigationEnabled: false
                            activeFocusOnTab: true
                            model: Gifs.list
                            currentIndex: Gifs.sel
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_Left) Gifs.step(-1);
                                else if (e.key === Qt.Key_Right) Gifs.step(1);
                                else return;
                                e.accepted = true;
                            }
                            delegate: Rectangle {
                                id: th
                                required property string modelData
                                required property int index
                                readonly property bool on: index === Gifs.sel
                                width: 58
                                height: 58
                                radius: Skin.corner(width * 0.18)
                                color: Skin.s1
                                border { width: on ? 2 : 1; color: on ? Skin.fg : Skin.s2 }
                                GifDots { anchors { fill: parent; margins: 6 } path: th.modelData; bg: th.color; playing: gifPick.visible && root.visible }
                                TapHandler {
                                    onTapped: {
                                        Gifs.pick(th.modelData);
                                        gifStrip.forceActiveFocus();
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                    Item { width: 1; height: 40 }
                    Lb { text: home.off.length ? `off grid · ${home.off.length}` : "everything fits" }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: home.off
                            Tile { cell: 84; gap: 8 }
                        }
                    }
                }
            }

            Tray {
                ids: Object.keys(Skin.kinds)
                icons: root.icons
                used: root.list("widgets")
                dim: home.off.map(c => c.id)
                widths: Skin.kinds
                onToggled: key => home.cur = root.flip("widgets", key, home.cur)
            }
        }

        // ---- DECK: a screen, deck at the bottom centre, quick settings on the right; both poke out when their edge is hovered.
        // deck sections in panel order; the tray is what there is ----
        Page {
            id: deck
            k: 1
            caption: `deck · ${Skin.state.deck.length} of ${Skin.decks.length} sections · bottom edge`
            property int cur: 0
            // dragging section from (-1 — nobody): dx — the cursor offset in mock-up px, at — where it sits in the strip, to — where it will land
            property int from: -1
            property real dx: 0
            readonly property real at: Math.max(10, Math.min(10 + (Skin.state.deck.length - 1) * 104, 10 + from * 104 + dx))
            readonly property int to: Math.round((at - 10) / 104)

            Row {
                spacing: 40

                Mini {
                    // the edges that catch the cursor: bottom — deck, right — quick settings
                    Seg {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                        width: 320
                        height: 4
                        n: 24
                        f: Skin.state.deckHover ? 1 : 0
                    }
                    Seg {
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        width: 4
                        height: 240
                        n: 16
                        vertical: true
                        f: Skin.state.quickHover ? 1 : 0
                    }

                    Rectangle {
                        id: strip
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
                        width: Math.max(1, Skin.state.deck.length) * 104 + 20
                        height: 116
                        radius: Skin.corner(40)
                        color: Skin.s1
                        border { width: 1; color: strip.activeFocus ? Skin.fg : Skin.s2 }
                        Behavior on width { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                        activeFocusOnTab: true
                        Keys.onPressed: e => {
                            const c = root.nav(e, "deck", deck.cur, Skin.decks);
                            if (c < 0) return;
                            deck.cur = c;
                            e.accepted = true;
                        }

                        Lb { visible: !Skin.state.deck.length; anchors.centerIn: parent; text: "empty" }
                        Repeater {
                            model: Skin.state.deck
                            Item {
                                id: ds
                                required property string modelData
                                required property int index
                                readonly property bool on: deck.cur === index
                                readonly property bool hot: on && strip.activeFocus
                                // while dragging: this one rides behind the cursor, the ones between it and the drop point shift a step toward its slot
                                readonly property int slot: deck.from < 0 ? index
                                    : index > deck.from && index <= deck.to ? index - 1
                                    : index < deck.from && index >= deck.to ? index + 1 : index
                                x: dd.active ? deck.at : 10 + slot * 104
                                width: 104
                                height: strip.height
                                z: dd.active ? 1 : 0
                                Behavior on x {
                                    enabled: !dd.active
                                    NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 56
                                        height: 56
                                        radius: 28
                                        color: ds.hot ? Skin.fg : Skin.s2
                                        border { width: ds.on && !ds.hot ? 1 : 0; color: Skin.fg }
                                        Icon { anchors.centerIn: parent; text: root.icons[ds.modelData] ?? ""; font.pixelSize: 24; color: ds.hot ? Skin.ink : Skin.fg }
                                    }
                                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: ds.modelData; px: 10; color: ds.on ? Skin.fg : Skin.grey }
                                }
                                TapHandler {
                                    onTapped: {
                                        strip.forceActiveFocus();
                                        deck.cur = deck.cur === ds.index ? root.cycle("deck", ds.index, Skin.decks) : ds.index;
                                    }
                                }
                                DragHandler {
                                    id: dd
                                    target: null
                                    yAxis.enabled: false
                                    // no target means the offset is scene px, and Stage is scaled
                                    onActiveTranslationChanged: deck.dx = activeTranslation.x / Skin.s
                                    onActiveChanged: {
                                        if (active) {
                                            deck.cur = ds.index;
                                            deck.from = ds.index;
                                            return;
                                        }
                                        // the drop lands after the signal: changing the list rebuilds the sections, this one included
                                        const from = deck.from, to = deck.to;
                                        Qt.callLater(() => {
                                            deck.from = -1;
                                            deck.cur = root.move("deck", from, to);
                                        });
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    spacing: 14
                    Toggle { width: 200; text: "deck · hover"; on: Skin.state.deckHover; onFlip: Skin.state.deckHover = !Skin.state.deckHover }
                    Toggle { width: 200; text: "quick · hover"; on: Skin.state.quickHover; onFlip: Skin.state.quickHover = !Skin.state.quickHover }
                    Lb { topPadding: 6; text: "bottom edge · right edge"; px: 10 }
                }
            }

            Tray {
                ids: Skin.decks
                icons: root.icons
                used: Skin.state.deck
                onToggled: key => deck.cur = root.flip("deck", key, deck.cur)
            }
        }

        // ---- BAR: the edge — two screens in miniature, a click picks. the tray as in the bar: left — a column (labels beside), top —
        // a row (labels under the icon), in order; drag — along the bar. the tray is what there is ----
        Page {
            id: bar
            k: 2
            caption: `bar · ${Skin.state.bar.length} of ${Skin.bars.length} in the tray · ${onTop ? "top" : "left"} edge`
            readonly property bool onTop: Skin.state.barAt === "top"
            readonly property real step: onTop ? 104 : 68 // a slot along the bar
            property int cur: 0
            // dragging from (-1 — nobody): d — the cursor offset along the bar in mock-up px, at — where it is, to — where it will land
            property int from: -1
            property real d: 0
            readonly property real at: Math.max(10, Math.min(10 + (Skin.state.bar.length - 1) * step, 10 + from * step + d))
            readonly property int to: Math.round((at - 10) / step)

            Grid {
                columns: bar.onTop ? 1 : 2
                columnSpacing: 200
                rowSpacing: 40

                Rectangle {
                    id: col
                    readonly property int n: Math.max(1, Skin.state.bar.length)
                    width: bar.onTop ? n * 104 + 20 : 88
                    height: bar.onTop ? 116 : n * 68 + 20
                    radius: Skin.corner(bar.onTop ? 40 : 44)
                    color: Skin.s1
                    border { width: 1; color: col.activeFocus ? Skin.fg : Skin.s2 }
                    Behavior on width { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                    Behavior on height { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                    activeFocusOnTab: true
                    Keys.onPressed: e => {
                        const c = root.nav(e, "bar", bar.cur, Skin.bars);
                        if (c < 0) return;
                        bar.cur = c;
                        e.accepted = true;
                    }

                    Lb { visible: !Skin.state.bar.length; anchors.centerIn: parent; text: "empty"; px: 10 }
                    Repeater {
                        model: Skin.state.bar
                        Item {
                            id: bs
                            required property string modelData
                            required property int index
                            readonly property bool on: bar.cur === index
                            readonly property bool hot: on && col.activeFocus
                            readonly property int slot: bar.from < 0 ? index
                                : index > bar.from && index <= bar.to ? index - 1
                                : index < bar.from && index >= bar.to ? index + 1 : index
                            // the spot along the bar: behind the cursor while dragging
                            property real pos: bd.active ? bar.at : 10 + slot * bar.step
                            Behavior on pos {
                                enabled: !bd.active
                                NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide }
                            }
                            x: bar.onTop ? pos : 0
                            y: bar.onTop ? 0 : pos
                            width: bar.onTop ? 104 : col.width
                            height: bar.onTop ? col.height : 68
                            z: bd.active ? 1 : 0

                            Rectangle {
                                id: bdot
                                x: (parent.width - width) / 2
                                y: bar.onTop ? 18 : (parent.height - height) / 2
                                width: 52
                                height: 52
                                radius: 26
                                color: bs.hot ? Skin.fg : Skin.s2
                                border { width: bs.on && !bs.hot ? 1 : 0; color: Skin.fg }
                                Icon { anchors.centerIn: parent; text: root.icons[bs.modelData] ?? ""; font.pixelSize: 22; color: bs.hot ? Skin.ink : Skin.fg }
                            }
                            Lb {
                                x: bar.onTop ? (parent.width - width) / 2 : parent.width + 24
                                y: bar.onTop ? bdot.y + bdot.height + 10 : (parent.height - height) / 2
                                text: bs.modelData
                                px: 10
                                color: bs.on ? Skin.fg : Skin.grey
                            }
                            TapHandler {
                                onTapped: {
                                    col.forceActiveFocus();
                                    bar.cur = bar.cur === bs.index ? root.cycle("bar", bs.index, Skin.bars) : bs.index;
                                }
                            }
                            DragHandler {
                                id: bd
                                target: null
                                xAxis.enabled: bar.onTop
                                yAxis.enabled: !bar.onTop
                                onActiveTranslationChanged: bar.d = (bar.onTop ? activeTranslation.x : activeTranslation.y) / Skin.s
                                onActiveChanged: {
                                    if (active) {
                                        bar.cur = bs.index;
                                        bar.from = bs.index;
                                        return;
                                    }
                                    const from = bar.from, to = bar.to;
                                    Qt.callLater(() => {
                                        bar.from = -1;
                                        bar.cur = root.move("bar", from, to);
                                    });
                                }
                            }
                        }
                    }
                }

                Column {
                    spacing: 14
                    Lb { text: "edge" }
                    // the screens with the pill at their edge; ←→ — the other one
                    Row {
                        id: edges
                        spacing: 20
                        activeFocusOnTab: true
                        Keys.onPressed: e => {
                            if (e.key !== Qt.Key_Left && e.key !== Qt.Key_Right && e.key !== Qt.Key_Space && e.key !== Qt.Key_Return) return;
                            Skin.state.barAt = bar.onTop ? "left" : "top";
                            e.accepted = true;
                        }
                        Repeater {
                            model: ["left", "top"]
                            Column {
                                id: ed
                                required property string modelData
                                readonly property bool on: (modelData === "top") === bar.onTop
                                spacing: 10
                                Rectangle {
                                    width: 200
                                    height: 125
                                    radius: 18
                                    color: Skin.bg
                                    border { width: ed.on && edges.activeFocus ? 2 : 1; color: ed.on ? Skin.fg : Skin.s3 }
                                    Behavior on border.color { ColorAnimation { duration: Skin.t } }
                                    Rectangle {
                                        x: 10
                                        y: 10
                                        width: ed.modelData === "top" ? parent.width - 20 : 16
                                        height: ed.modelData === "top" ? 16 : parent.height - 20
                                        radius: Skin.corner(8)
                                        color: ed.on ? Skin.fg : Skin.s3
                                        Behavior on color { ColorAnimation { duration: Skin.t } }
                                    }
                                    TapHandler { onTapped: Skin.state.barAt = ed.modelData }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: ed.modelData; px: 10; color: ed.on ? Skin.fg : Skin.grey }
                            }
                        }
                    }
                    Item { width: 1; height: 12 }
                    Toggle { width: 200; text: "window title"; on: Skin.state.barTitle; onFlip: Skin.state.barTitle = !Skin.state.barTitle }
                    Lb { topPadding: 6; text: bar.onTop ? "left of the clock" : "above the clock"; px: 10 }
                }
            }

            Tray {
                ids: Skin.bars
                icons: root.icons
                used: Skin.state.bar
                onToggled: key => bar.cur = root.flip("bar", key, bar.cur)
            }
        }

        // ---- LOOK: the miniature home follows the toggles; the name goes in the pill ----
        Page {
            id: look
            k: 3
            caption: "look · the home screen, live"
            property bool dim: false // the colon is out
            Timer { running: look.visible && root.visible && Skin.state.blink; interval: 500; repeat: true; onTriggered: look.dim = !look.dim }

            Row {
                spacing: 40

                Mini {
                    Orb { visible: Skin.state.orb; x: 400; y: 110; scale: 330 / 1100; transformOrigin: Item.TopLeft }
                    Row {
                        x: 60
                        y: 52
                        Num { id: hrs; text: Skin.hh(clock.date); font.pixelSize: 120 }
                        Num { text: ":"; font.pixelSize: 120; opacity: Skin.state.blink && look.dim ? 0.2 : 1 }
                        Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 120 }
                        Lb { visible: !Skin.state.clock24; anchors.baseline: hrs.baseline; leftPadding: 12; text: clock.date.getHours() < 12 ? "am" : "pm" }
                    }
                    Lb { x: 64; y: 172; text: Qt.locale("en_US").toString(clock.date, "dddd · d MMMM"); px: 11 }
                    Text {
                        x: 62
                        y: 232
                        textFormat: Text.StyledText
                        text: `${root.hello},<br><font color="${Skin.grey}">${root.who}.</font>`
                        font { family: Skin.ui; pixelSize: 30; weight: Font.Light }
                        lineHeight: 1.1
                        color: Skin.fg
                    }
                    // Pulse strips: volume on the right, progress along the bottom
                    Seg { visible: Skin.state.edges; x: parent.width - 12; y: 140; width: 4; height: 200; n: 12; f: 0.6; vertical: true }
                    Seg { visible: Skin.state.edges; x: 230; y: parent.height - 10; width: 300; height: 4; n: 24; f: 0.4 }
                }

                Column {
                    spacing: 14
                    Toggle { width: 200; text: "light"; on: Skin.light; onFlip: Skin.setLight(!Skin.light) }
                    Toggle { width: 200; text: "dot grid"; on: Skin.state.grid; onFlip: Skin.state.grid = !Skin.state.grid }
                    Toggle { width: 200; text: "orb"; on: Skin.state.orb; onFlip: Skin.state.orb = !Skin.state.orb }
                    Toggle { width: 200; text: "24 hours"; on: Skin.state.clock24; onFlip: Skin.state.clock24 = !Skin.state.clock24 }
                    Toggle { width: 200; text: "blink"; on: Skin.state.blink; onFlip: Skin.state.blink = !Skin.state.blink }
                    Toggle { width: 200; text: "edges"; on: Skin.state.edges; onFlip: Skin.state.edges = !Skin.state.edges }
                    Act {
                        icon: "\u{F02E9}"
                        text: "wallpaper"
                        onHit: {
                            root.close();
                            root.wallRequested();
                        }
                    }
                }
            }

            // the name in the greeting; empty — $USER
            Rectangle {
                width: 760
                height: 72
                radius: Skin.corner(36)
                color: Skin.s2
                border { width: name.activeFocus ? 1 : 0; color: Skin.fg }
                Lb { id: nameL; x: 30; anchors.verticalCenter: parent.verticalCenter; text: "name"; color: name.activeFocus ? Skin.fg : Skin.grey }
                TextInput {
                    id: name
                    anchors { left: nameL.right; leftMargin: 24; right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
                    text: Skin.state.name
                    maximumLength: 24
                    activeFocusOnTab: true
                    font { family: Skin.ui; pixelSize: 24 }
                    color: Skin.fg
                    selectionColor: Skin.s3
                    clip: true
                    onTextEdited: Skin.state.name = text
                    cursorDelegate: Rectangle {
                        width: 2
                        color: name.activeFocus ? Skin.accent : "transparent"
                        Timer { running: name.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text { visible: !name.text; text: Quickshell.env("USER"); font: name.font; color: Skin.mute }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) root.go(root.sel + (e.key === Qt.Key_Up ? -1 : 1));
                        else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) stage.forceActiveFocus();
                        else return;
                        e.accepted = true;
                    }
                }
            }
        }

        // ---- EDGE LIGHTS: how the strip up top announces a notification. the preview plays the pattern under the
        // cursor with the same math the real strip runs (edge/flash.js) — what you see is what you get ----
        Page {
            k: 4
            caption: "edge lights · the notification flash"

            Column {
                spacing: 30

                Item {
                    width: 640
                    height: 52

                    Seg {
                        id: prev
                        x: 20
                        y: 6
                        width: 600
                        height: 8
                        n: 12
                        on: Skin.fg
                        layer.enabled: true
                        layer.effect: Glow {}
                        property real ph: 0
                        SequentialAnimation on ph {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 1; duration: 3000 }
                        }
                        readonly property string live: root.flashHover || Skin.state.flash || "breathe"
                        readonly property var sh: FlashShape.shape(live, ph)
                        f: sh.f
                        opacity: sh.o
                    }
                    Lb {
                        x: 20
                        y: 30
                        text: prev.live + (prev.live === (Skin.state.flash || "breathe") ? " · live" : " · preview")
                        px: 10
                        opacity: 0.7
                    }
                }

                Row {
                    spacing: 14

                    Repeater {
                        model: FlashShape.NAMES

                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool on: (Skin.state.flash || "breathe") === modelData[0]
                            readonly property bool hot: chipHov.hovered || chip.activeFocus
                            width: 200
                            height: 94
                            radius: Skin.corner(24)
                            color: on ? Skin.fg : hot ? Skin.s3 : Skin.s2
                            border { width: activeFocus ? 1 : 0; color: Skin.fg }
                            Behavior on color { ColorAnimation { duration: Skin.t } }
                            activeFocusOnTab: true

                            Column {
                                anchors.centerIn: parent
                                spacing: 7
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: chip.modelData[0]; color: chip.on ? Skin.ink : chip.hot ? Skin.fg : Skin.grey; px: 13 }
                                Lb { width: chip.width - 24; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: chip.modelData[1]; color: chip.on ? Skin.mute : Skin.mute; px: 9 }
                            }
                            HoverHandler {
                                id: chipHov
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered) root.flashHover = chip.modelData[0];
                                    else if (root.flashHover === chip.modelData[0]) root.flashHover = "";
                                }
                            }
                            TapHandler { onTapped: Skin.state.flash = chip.modelData[0] }
                            Keys.onPressed: e => {
                                if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space) return;
                                Skin.state.flash = chip.modelData[0];
                                e.accepted = true;
                            }
                        }
                    }
                }

                Row {
                    spacing: 24
                    Toggle { text: "edges"; on: Skin.state.edges; onFlip: Skin.state.edges = !Skin.state.edges }
                    Lb { anchors.verticalCenter: parent.verticalCenter; text: "one cycle, three seconds · criticals flash red"; px: 10; opacity: 0.7 }
                }
            }
        }

        // ---- STYLE: where the colour comes from and where it lands. on top — the desktop in the palette of the swatch under the
        // cursor or in focus (none — the current one): bar, quick settings, kitty, player, a Pulse strip; to its right the roles as
        // callouts, like on a blueprint: which colour goes where. under it the source and the theme; then what the source holds: the
        // wallpaper as dots (click — the picker), its tones and variants (the ring — how much colour) or palettes by group. the list
        // is the same style as in the launcher (Skin.styles).
        // swatches by index: a fresh Skin.styles on every pick doesn't rebuild the circles, and focus stays where it was ----
        Page {
            id: tint
            k: 5
            property Item hot: null // the swatch under the cursor or in focus
            readonly property var p: hot?.item.pal ?? Skin.pal
            readonly property string src: Skin.state.paint === "scheme" ? (Skin.pal.group === "more" ? "" : Skin.pal.group + " ") + Skin.pal.name
                : Skin.state.paint === "wall" && Skin.tones.length ? `wallpaper · ${Skin.pal.name}` : "nothing"
            caption: `style · ${src} · ${Skin.light ? "light" : "dark"}` + (hot && !hot.item.now ? `   →   ${hot.item.name} · ↵ sets it` : "")
            function block(h) { return Skin.styles.find(b => b.head === h)?.items ?? []; }
            function peek(sw) {
                if (sw.peek) hot = sw;
                else if (hot === sw) hot = null;
            }

            Desk { p: tint.p }

            Row {
                spacing: 24
                Pick {
                    label: "from"
                    opts: ["nothing", "wall", "palette"]
                    cur: ["", "wall", "scheme"].indexOf(Skin.state.paint)
                    onPicked: i => Skin.state.paint = ["", "wall", "scheme"][i]
                }
                Pick { label: "theme"; opts: ["dark", "light"]; cur: Skin.light ? 1 : 0; onPicked: i => Skin.setLight(i === 1) }
            }

            // what the source holds. one height for all of them: Page is centred, and the mock-up shouldn't jump when the source changes. loose end: 300 is
            // eyeballed, two rows of palettes; if it grows the Item grows after it
            Item {
                width: 1040
                height: Math.max(300, own.height)
                Column {
                    id: own
                    spacing: 28
                    Lb { visible: !Skin.state.paint; text: "black · white dots · one red — nothing to pick"; color: Skin.mute }
                    Row {
                        visible: Skin.state.paint === "wall"
                        spacing: 34
                        // the wallpaper as dots; click — the picker
                        Rectangle {
                            width: 168
                            height: 105
                            radius: Skin.corner(14)
                            color: "transparent"
                            border { width: Skin.wall ? 0 : 1; color: Skin.s3 }
                            Image {
                                anchors.fill: parent
                                source: visible ? Skin.url(Skin.wallSrc(Skin.wall)) : "" // not visible — no texture to load
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(336, 210)
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: Dm { step: 4 }
                            }
                            Lb { visible: !Skin.wall; anchors.centerIn: parent; px: 10; text: "no wallpaper" }
                            TapHandler {
                                onTapped: {
                                    root.close();
                                    root.wallRequested();
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                        Column {
                            spacing: 6
                            Lb { text: Skin.tones.length ? "tones · from the wallpaper" : "no colour in it · click it for another" }
                            Row {
                                Repeater {
                                    model: tint.block("tones").length
                                    Swatch { id: tw; item: tint.block("tones")[index] ?? ({ name: "" }); onPeekChanged: tint.peek(tw) }
                                }
                            }
                        }
                    }
                    Column {
                        visible: Skin.state.paint === "wall" && Skin.tones.length > 0
                        spacing: 6
                        Lb { text: "variant · how much colour, like material you" }
                        Row {
                            Repeater {
                                model: tint.block("variant").length
                                Swatch { id: vw; item: tint.block("variant")[index] ?? ({ name: "" }); onPeekChanged: tint.peek(vw) }
                            }
                        }
                    }
                    // the palettes by group — blocks between source and theme
                    Flow {
                        visible: Skin.state.paint === "scheme"
                        width: 1040
                        spacing: 40
                        Repeater {
                            model: Skin.state.paint === "scheme" ? Skin.styles.length - 2 : 0
                            Column {
                                id: sb
                                required property int index
                                readonly property var block: Skin.styles[index + 1] ?? ({ head: "", items: [] })
                                spacing: 6
                                Lb { text: sb.block.head }
                                Row {
                                    Repeater {
                                        model: sb.block.items.length
                                        Swatch { id: pw; item: sb.block.items[index] ?? ({ name: "" }); onPeekChanged: tint.peek(pw) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- WINDOWS: a desktop with two windows following the live ring values. the windows animate only when motion is on ----
        Page {
            k: 6
            caption: `windows · hyprland · gaps ${gIn.v} / ${gOut.v} · border ${bord.v} · rounding ${rnd.v} · panels ${pan.v} %`

            Row {
                spacing: 40

                Mini {
                    id: desk
                    Repeater {
                        model: 2
                        Rectangle {
                            id: wnd
                            required property int index
                            readonly property real o: gOut.v * desk.k
                            readonly property real l: 78 * Skin.s * desk.k + o // bar 64 + inset 14, in logical px
                            readonly property real w: (desk.width - (at === "top" ? o : l) - o - 2 * gIn.v * desk.k) / 2
                            readonly property string at: Skin.state.barAt
                            x: (at !== "top" ? l : o) + (index ? w + 2 * gIn.v * desk.k : 0)
                            y: at === "top" ? l : o
                            width: w
                            height: desk.height - (at === "top" ? l : o) - o
                            radius: rnd.v * desk.k
                            color: Skin.s1
                            border { width: bord.v ? Math.max(1, bord.v * desk.k) : 0; color: index ? Skin.s3 : Skin.fg }
                            Behavior on x { enabled: root.r.motion; NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                            Behavior on y { enabled: root.r.motion; NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                            Behavior on width { enabled: root.r.motion; NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                            Behavior on height { enabled: root.r.motion; NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }

                            Column {
                                x: 20
                                y: 20
                                spacing: 9
                                Lb { text: wnd.index ? "zen" : "kitty"; px: 10; color: wnd.index ? Skin.mute : Skin.grey }
                                Repeater {
                                    model: [0.7, 0.45, 0.85, 0.3, 0.6, 0.5]
                                    Rectangle {
                                        required property real modelData
                                        width: (wnd.width - 40) * modelData
                                        height: 5
                                        radius: 2.5
                                        color: Skin.s3
                                    }
                                }
                            }
                        }
                    }
                }

                // loose end: blur and shadows don't show in the mock-up (flat black) — toggles only
                Column {
                    spacing: 14
                    Toggle { width: 200; text: "blur"; on: root.r.blur; onFlip: { root.r.blur = !root.r.blur; Skin.apply(); } }
                    Toggle { width: 200; text: "shadow"; on: root.r.shadow; onFlip: { root.r.shadow = !root.r.shadow; Skin.apply(); } }
                    Toggle { width: 200; text: "motion"; on: root.r.motion; onFlip: { root.r.motion = !root.r.motion; Rules.motion(); } }
                }
            }

            Row {
                spacing: 40
                Dial { id: gIn; label: "gaps in"; to: 30; value: root.r.gapsIn; onMoved: v => { root.r.gapsIn = v; Skin.apply(); } }
                Dial { id: gOut; label: "gaps out"; to: 60; value: root.r.gapsOut; onMoved: v => { root.r.gapsOut = v; Skin.apply(); } }
                Dial { id: bord; label: "border"; to: 6; n: 24; value: root.r.border; onMoved: v => { root.r.border = v; Skin.apply(); } }
                Dial { id: rnd; label: "rounding"; to: 40; value: Skin.state.rounding; onMoved: v => Skin.state.rounding = v } // shell.qml calls Skin.apply itself
                Dial { id: pan; label: "panels"; to: 100; step: 5; value: Skin.state.corners; onMoved: v => Skin.state.corners = v } // the shell's corners, %
            }
        }

        // ---- DISPLAY: the screens as hypr laid them out (click or ←→ — pick); everything below is the picked one's: brightness (built-in),
        // logical px, scale and hz, the bar and home on it. night light — all of them ----
        Page {
            id: disp
            k: 7
            readonly property var m: Rules.mons.find(x => x.name === root.mon) ?? Rules.mon
            readonly property var w: Rules.want(m)
            caption: `display · ${m.name.toLowerCase()} · ${m.w} × ${m.h} · ${m.hz} hz`

            Row {
                spacing: 60
                Column {
                    z: 1 // a screen dragged past the map's edge rides above the brightness ring
                    spacing: 22
                    Item {
                        id: map
                        readonly property var ms: Rules.mons
                        // dragging screen held: at — where it would land (logical px); i hold it there until hypr answers with new monitors
                        property string held: ""
                        property var at: null
                        onMsChanged: held = ""
                        readonly property real x0: Math.min(...ms.map(m => m.x))
                        readonly property real y0: Math.min(...ms.map(m => m.y))
                        readonly property real bw: Math.max(...ms.map(m => m.x + m.lw)) - x0
                        readonly property real bh: Math.max(...ms.map(m => m.y + m.lh)) - y0
                        readonly property real k: Math.min(width / bw, height / bh)
                        width: 560
                        height: 320
                        activeFocusOnTab: true
                        Keys.onPressed: e => {
                            const d = e.key === Qt.Key_Left ? -1 : e.key === Qt.Key_Right ? 1 : 0, n = root.names.length;
                            if (!d || !n) return;
                            root.pickMon = root.names[(root.names.indexOf(root.mon) + d + n) % n];
                            e.accepted = true;
                        }
                        Repeater {
                            model: map.ms
                            Rectangle {
                                id: sc
                                required property var modelData
                                readonly property bool on: modelData.name === root.mon
                                readonly property var p: map.held === modelData.name && map.at ? map.at : modelData
                                x: (map.width - map.bw * map.k) / 2 + (p.x - map.x0) * map.k + 5
                                y: (map.height - map.bh * map.k) / 2 + (p.y - map.y0) * map.k + 5
                                z: map.held === modelData.name ? 1 : 0
                                width: modelData.lw * map.k - 10
                                height: modelData.lh * map.k - 10
                                radius: Skin.corner(18)
                                color: Skin.bg
                                border { width: sc.on && map.activeFocus ? 2 : 1; color: sc.on ? Skin.fg : Skin.s3 }
                                Behavior on border.color { ColorAnimation { duration: Skin.t } }
                                Image {
                                    anchors { fill: parent; margins: 12 }
                                    fillMode: Image.Tile
                                    source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle cx="5" cy="5" r="1.5" fill="#${Skin.hex(sc.on ? Skin.mute : Skin.s2)}"/></svg>`)
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: sc.modelData.name; color: sc.on ? Skin.fg : Skin.grey }
                                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: `${sc.modelData.w} × ${sc.modelData.h}`; px: 10 }
                                }
                                TapHandler {
                                    onTapped: {
                                        root.pickMon = sc.modelData.name;
                                        map.forceActiveFocus();
                                    }
                                }
                                HoverHandler { cursorShape: root.multi ? Qt.OpenHandCursor : Qt.PointingHandCursor }
                                // drag — it snaps flush against a neighbour (Rules.dock); drop — Rules.place. it won't drag while hypr hasn't
                                // answered the last drop: the math would run off stale spots. no target means the offset is scene px, and
                                // Stage is scaled
                                DragHandler {
                                    target: null
                                    enabled: root.multi && (!map.held || active)
                                    cursorShape: Qt.ClosedHandCursor
                                    onActiveTranslationChanged: {
                                        if (!active) return;
                                        const m = sc.modelData, k = Skin.s * map.k;
                                        map.at = Rules.dock({ x: m.x + activeTranslation.x / k, y: m.y + activeTranslation.y / k, w: m.lw, h: m.lh },
                                                           map.ms.filter(o => o.name !== m.name), 16 / map.k);
                                    }
                                    onActiveChanged: {
                                        const m = sc.modelData;
                                        if (active) {
                                            root.pickMon = m.name;
                                            map.at = null;
                                            map.held = m.name;
                                            return;
                                        }
                                        if (map.at && (map.at.x !== m.x || map.at.y !== m.y)) Rules.place(m.name, map.at.x, map.at.y);
                                        else map.held = "";
                                    }
                                }
                            }
                        }
                    }
                    Row {
                        spacing: 14
                        Num { id: resW; text: disp.m.lw; font.pixelSize: 72 }
                        Num { anchors.baseline: resW.baseline; text: "×"; font.pixelSize: 40; color: Skin.mute }
                        Num { anchors.baseline: resW.baseline; text: disp.m.lh; font.pixelSize: 72 }
                    }
                    Lb { text: "logical pixels" }
                }
                // the backlight — built-in panels; external over DDC — no (services/Backlight)
                Column {
                    visible: Sys.hasBri && disp.m.name === Rules.mon.name
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 22
                    Dial { anchors.horizontalCenter: parent.horizontalCenter; size: 300; n: 60; live: true; label: "brightness"; value: Math.round(Sys.bri * 100); onMoved: v => Sys.setBri(v / 100) }
                    // the brightness key step: notches on the scale (Backlight.steps)
                    Pick { anchors.horizontalCenter: parent.horizontalCenter; label: "step"; opts: ["2.5%", "5%", "10%"]; cur: [40, 20, 10].indexOf(Skin.state.briSteps); onPicked: i => Skin.state.briSteps = [40, 20, 10][i] }
                }
            }
            Row {
                spacing: 24
                Pick { label: "scale"; opts: Rules.scales; cur: disp.w.scale ? Rules.scales.indexOf(String(disp.w.scale)) : 0; onPicked: i => Rules.set(disp.m.name, "scale", i ? +Rules.scales[i] : 0) }
                // there can be five refresh rates, or eight (a tv, 165 hz) — segments here, so the row stays inside the canvas
                Pick { label: "hz"; seg: Math.min(104, 416 / opts.length); opts: disp.m.rates.map(String); cur: disp.m.rates.indexOf(disp.w.refresh); onPicked: i => Rules.set(disp.m.name, "refresh", disp.m.rates[i]) }
            }
            // and on a single screen: the bar came off a docked laptop, it undocked — only here can it be brought back
            Row {
                spacing: 20
                Toggle { text: "bar"; on: Skin.scr(root.mon, "bar"); onFlip: Skin.setScr(root.mon, "bar", !on) }
                Toggle { text: "home"; on: Skin.scr(root.mon, "home"); onFlip: Skin.setScr(root.mon, "home", !on) }
                Lb { anchors.verticalCenter: parent.verticalCenter; leftPadding: 10; text: "on this screen · its widgets — in home" }
                // forget the externals' own spots, scale and hz — back to what the hypr config says (Rules.forget)
                Act { visible: Object.keys(Rules.store.outs).length > 0; icon: "\u{F0450}"; text: "hypr config"; onHit: Rules.forget() }
            }
            Row {
                spacing: 40
                Toggle { anchors.verticalCenter: parent.verticalCenter; text: "night light"; on: Sys.night; onFlip: Sys.toggleNight() }
                Dial { label: "warmth · k · all screens"; from: 2500; to: 6500; step: 100; value: root.r.warmth; onMoved: v => { root.r.warmth = v; if (root.r.night) Rules.night(); } }
            }
        }

        // ---- AUDIO: output and input — volume, mute, level, the default device (prefs/Audio) ----
        Page {
            id: audioPage
            k: 8
            caption: aud.caption
            Audio { id: aud; live: audioPage.visible && root.shown }
        }

        // ---- POWER: the power modes (Rules.modes) — four circles, the ring lit by strength, the picked one white.
        // ultra — power saver plus 60 hz, no animations, blur or shadows over these settings ----
        Page {
            k: 9
            caption: `power · ${Rules.modes[Rules.mode].what} · ${Rules.hz} hz`

            Row {
                spacing: 32
                Repeater {
                    model: Rules.modes.slice(0, Rules.modeCount)
                    Rectangle {
                        id: pc
                        required property var modelData
                        required property int index
                        readonly property bool on: Rules.mode === index
                        width: 230
                        height: 230
                        radius: 115
                        color: on ? Skin.fg : Skin.s1
                        border { width: activeFocus ? 2 : 1; color: activeFocus || on ? Skin.fg : Skin.s2 }
                        Behavior on color { ColorAnimation { duration: Skin.t } }
                        activeFocusOnTab: true
                        Keys.onPressed: e => {
                            if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space) return;
                            Rules.setMode(index);
                            e.accepted = true;
                        }
                        Ring { anchors { fill: parent; margins: 14 } n: 40; dot: 6; f: (pc.index + 1) / 4; on: pc.on ? Skin.ink : Skin.fg; off: pc.on ? Skin.mute : Skin.s3 }
                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            Num { anchors.horizontalCenter: parent.horizontalCenter; text: pc.modelData.short; font.pixelSize: 54; color: pc.on ? Skin.ink : Skin.fg }
                            Lb { anchors.horizontalCenter: parent.horizontalCenter; text: pc.modelData.name; color: pc.on ? Skin.ink : Skin.grey }
                        }
                        TapHandler { onTapped: Rules.setMode(pc.index) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
            Lb { text: Rules.store.ultra ? `ultra · ${Rules.rates[0]} hz, no motion, no blur, no shadows — your settings come back when you leave` : "cpu profile only · hz, motion and looks stay yours" }
            Lb { visible: !PowerProfiles.hasPerformanceProfile; text: "no performance profile on this machine" }
        }

        // ---- INPUT: hold a key — the first dot right away, a delay pause, then rate a second; played out on live rings ----
        Page {
            id: inp
            k: 10
            caption: "input · keyboard · touchpad"
            property int n: 0 // how much is "typed"; 0 — the key is up
            Timer {
                running: inp.visible && root.visible
                repeat: true
                interval: inp.n === 0 ? 700 : inp.n === 1 ? delay.v : 1000 / rate.v
                onTriggered: inp.n = (inp.n + 1) % 41
            }

            Row {
                spacing: 30
                Rectangle {
                    width: 110
                    height: 110
                    radius: 30
                    color: inp.n ? Skin.fg : Skin.s1
                    border { width: 1; color: Skin.s2 }
                    Num { anchors.centerIn: parent; text: "A"; font.pixelSize: 54; color: inp.n ? Skin.ink : Skin.fg }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16
                    Row {
                        spacing: 6
                        Repeater {
                            model: 40
                            Rectangle {
                                required property int index
                                width: 14
                                height: 14
                                radius: 7
                                color: index < inp.n ? Skin.fg : Skin.s2
                            }
                        }
                    }
                    Lb { text: `hold a key · first, ${delay.v} ms, then ${rate.v} a second` }
                }
            }
            Row {
                spacing: 40
                Dial { id: delay; label: "delay · ms"; from: 150; to: 600; step: 10; value: root.r.repeatDelay; onMoved: v => { root.r.repeatDelay = v; Rules.input(); } }
                Dial { id: rate; label: "rate · /s"; from: 10; to: 60; value: root.r.repeatRate; onMoved: v => { root.r.repeatRate = v; Rules.input(); } }
                Dial { label: "scroll · %"; from: 10; to: 100; step: 5; value: root.r.scroll; onMoved: v => { root.r.scroll = v; Rules.input(); } }
                Dial { label: "pointer"; from: -100; to: 100; step: 5; value: root.r.sens; onMoved: v => { root.r.sens = v; Rules.input(); } }
            }
            Row {
                spacing: 20
                Toggle { text: "natural scroll"; on: root.r.natural; onFlip: { root.r.natural = !root.r.natural; Rules.input(); } }
                Toggle { text: "tap to click"; on: root.r.tap; onFlip: { root.r.tap = !root.r.tap; Rules.input(); } }
                Toggle { text: "off while typing"; on: root.r.typingOff; onFlip: { root.r.typingOff = !root.r.typingOff; Rules.input(); } }
                Toggle { text: "flat accel"; on: root.r.flat; onFlip: { root.r.flat = !root.r.flat; Rules.input(); } }
            }
            Pick { label: "layout switch"; opts: Rules.switches.map(s => s[0]); cur: root.r.kbSwitch; onPicked: i => { root.r.kbSwitch = i; Rules.input(); } }
        }

        // ---- IDLE: a scale of minutes without input. the dots dim at every event: awake → locked → screen off → asleep.
        // the marks drag along, past 60 — never ----
        Page {
            k: 11
            caption: "idle · minutes without input · hypridle"

            Item {
                id: line
                width: 1000
                height: 300
                readonly property var at: [lk.v, dpms.v, zz.v]

                Repeater {
                    model: 61
                    Rectangle {
                        required property int index
                        readonly property int lvl: line.at.filter(m => m && m <= index).length
                        x: index * 15 - 4
                        y: 246
                        width: 8
                        height: 8
                        radius: 4
                        color: [Skin.fg, Skin.grey, Skin.mute, Skin.s3][lvl]
                    }
                }
                // never — an empty ring past the scale
                Rectangle { x: 62 * 15 - 7; y: 243; width: 14; height: 14; radius: 7; color: "transparent"; border { width: 1; color: Skin.mute } }
                Repeater {
                    model: [0, 15, 30, 45, 60]
                    Lb { required property int modelData; x: modelData * 15 - width / 2; y: 272; text: modelData; px: 10 }
                }
                Lb { x: 62 * 15 - width / 2; y: 272; text: "never"; px: 10 }

                Mark { id: lk; row: 0; label: "lock"; value: root.r.lockAfter; onMoved: v => { root.r.lockAfter = v; Rules.idle(); } }
                Mark { id: dpms; row: 1; label: "screen off"; value: root.r.dpmsAfter; onMoved: v => { root.r.dpmsAfter = v; Rules.idle(); } }
                Mark { id: zz; row: 2; label: Rules.hibernateOn ? "sleep · hibernate" : "sleep"; value: root.r.sleepAfter; onMoved: v => { root.r.sleepAfter = v; Rules.idle(); } }
            }
            Row {
                spacing: 26
                Repeater {
                    model: [["awake", Skin.fg], ["locked", Skin.grey], ["dark", Skin.mute], ["asleep", Skin.s3]]
                    Row {
                        required property var modelData
                        spacing: 10
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: parent.modelData[1] }
                        Lb { text: parent.modelData[0]; px: 10 }
                    }
                }
            }
            Row {
                spacing: 24
                Pick { label: "sleep into"; visible: Rules.canHibernate; opts: ["suspend", "hibernate"]; cur: root.r.hibernate ? 1 : 0; onPicked: i => { root.r.hibernate = i === 1; Rules.idle(); } }
                Toggle { text: "caffeine"; on: Sys.caffeine; onFlip: Sys.caffeine = !Sys.caffeine }
            }
        }

        // ---- SHELL: the rice's mark and the running shell's name; switching is the Rice app's job ----
        Page {
            k: 12
            caption: "shell · quickshell"

            Row {
                spacing: 50
                Item {
                    width: 260
                    height: 260
                    Ring { anchors.fill: parent; n: 16; dot: 14; f: 1 }
                    Rectangle { anchors.centerIn: parent; width: 52; height: 52; radius: 26; color: Skin.fg }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 18
                    Lb { text: "running now" }
                    Num { text: root.meta.name ?? "PULSE"; font.pixelSize: 140 }
                    Lb { text: root.meta.tagline ?? "" }
                }
            }
            Row {
                spacing: 20
                Act {
                    visible: root.shells > 1
                    icon: "\u{F04E1}"
                    text: "switch shell"
                    onHit: {
                        root.close();
                        Quickshell.execDetached(["qs", "-c", "rice"]);
                    }
                }
                Act { icon: "\u{F0450}"; text: "reload"; onHit: Quickshell.reload(false) }
                Toggle { text: "do not disturb"; on: Skin.state.dnd; onFlip: Skin.state.dnd = !Skin.state.dnd }
            }
        }
    }

    // the section on the right: only the picked one is visible (tab only walks visible items), it rises from below
    component Page: Column {
        required property int k
        property string caption
        x: 800
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: visible ? 0 : 24
        visible: root.sel === k
        opacity: visible ? 1 : 0
        spacing: 28
        Behavior on opacity { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
        Lb { text: parent.caption }
    }

    // a screen in miniature, 16:10: wallpaper (dot grid, if on) and the bar; k — logical screen px per mock-up px
    component Mini: Rectangle {
        readonly property real k: width / (Rules.mon.w ? Rules.mon.w / Rules.scale : Quickshell.screens[0]?.width ?? 1920)
        width: 760
        height: 475
        radius: 24
        color: Skin.bg
        border { width: 1; color: Skin.s3 }
        Image {
            visible: Skin.state.grid
            anchors { fill: parent; margins: 12 }
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><circle cx="8" cy="8" r="1" fill="#${Skin.hex(Skin.s2)}"/></svg>`)
        }
        // the bar at its edge: inset 14 and thickness 64 are mock-up px, on the screen Skin.s logical ones
        Rectangle {
            readonly property real u: Skin.s * parent.k
            readonly property bool onTop: Skin.state.barAt === "top"
            x: 14 * u
            y: 14 * u
            width: onTop ? parent.width - 28 * u : 64 * u
            height: onTop ? 64 * u : parent.height - 28 * u
            radius: Skin.corner(Math.min(width, height) / 2)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
        }
    }

    // an empty mock-up cell: 4 × 4 dead dots
    component Dots: Grid {
        columns: 4
        padding: 30
        spacing: 28
        Repeater {
            model: 16
            Rectangle { width: 6; height: 6; radius: 3; color: Skin.s3 }
        }
    }

    // a widget in the home mock-up: a circle or a 40 square (scaled), the icon as dots, the name. picked — a white outline,
    // focused — white all over. didn't fit — a pale outline
    component Tile: Rectangle {
        id: tile
        required property var modelData // { id, i, row, col, span, fits }
        property real cell: 168
        property real gap: 16
        readonly property bool on: home.cur === modelData.i
        readonly property bool hot: on && grid.activeFocus
        readonly property bool round: root.rounds.includes(modelData.id)
        width: modelData.span * cell + (modelData.span - 1) * gap
        height: cell
        radius: round ? cell / 2 : Skin.corner(cell * 0.18)
        color: hot ? Skin.fg : modelData.fits ? Skin.s1 : "transparent"
        border { width: on ? 2 : 1; color: on ? Skin.fg : modelData.fits ? Skin.s2 : Skin.mute }
        z: drag.active ? 1 : 0
        // no target means the offset is scene px, and Stage is scaled
        readonly property real dx: drag.activeTranslation.x / Skin.s
        readonly property real dy: drag.activeTranslation.y / Skin.s
        transform: Translate { x: drag.active ? tile.dx : 0; y: drag.active ? tile.dy : 0 }
        Behavior on color { ColorAnimation { duration: Skin.t } }

        Ring {
            visible: tile.round && tile.cell > 100
            anchors { fill: parent; margins: 10 }
            n: 40
            dot: 4
            f: 0.66
            on: tile.hot ? Skin.ink : Skin.fg
            off: tile.hot ? Skin.fade(Skin.ink, 0.15) : Skin.s3
        }
        Column {
            anchors.centerIn: parent
            spacing: 10
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.icons[tile.modelData.id] ?? "?"
                font.pixelSize: tile.cell * 0.26
                color: tile.hot ? Skin.ink : tile.modelData.fits ? Skin.fg : Skin.grey
                layer.enabled: true
                layer.effect: Dm { step: 3 }
            }
            Lb { visible: tile.cell > 100; anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.id; px: 10; color: tile.hot ? Skin.ink : Skin.grey }
        }
        TapHandler { onTapped: home.tap(tile.modelData.i) }
        // the drop lands after the signal: changing the list rebuilds the tiles, this one included
        DragHandler {
            id: drag
            target: null
            onActiveChanged: {
                if (active) {
                    home.cur = tile.modelData.i;
                    return;
                }
                const p = grid.mapFromItem(tile.parent, tile.x + tile.width / 2 + tile.dx, tile.y + tile.height / 2 + tile.dy);
                Qt.callLater(home.land, tile.modelData.i, p);
            }
        }
    }

    // an idle mark: a leg down to the scale, a Doto number and a name. drag along the scale, ←→ — a minute; past 60 — never (0).
    // while dragging it keeps its own v; rules.json and hypridle get it on release or after 400 ms of quiet
    component Mark: Item {
        id: mk
        property int row
        property string label
        property int value
        property int v: value
        signal moved(int v)
        function put(m) {
            m = m > 60.5 ? 0 : Math.max(1, Math.round(m));
            if (m === v) return;
            v = m;
            wait.restart();
        }
        onValueChanged: if (!ma.pressed && !wait.running) v = value
        Timer { id: wait; interval: 400; onTriggered: if (!ma.pressed && mk.v !== mk.value) mk.moved(mk.v) }

        x: (v || 62) * 15
        y: row * 76
        width: 160
        height: 250 - y
        activeFocusOnTab: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Left) put(v ? v - 1 : 60);
            else if (e.key === Qt.Key_Right) put(v ? v + 1 : 61);
            else return;
            e.accepted = true;
        }
        Behavior on x { NumberAnimation { duration: 120 } }

        Rectangle { width: 1; height: parent.height; color: mk.activeFocus || ma.pressed ? Skin.fg : Skin.mute }
        Column {
            x: 12
            Num { text: mk.v || "—"; font.pixelSize: 44 }
            Lb { topPadding: 6; text: mk.label; px: 10; color: mk.activeFocus ? Skin.fg : Skin.grey }
        }
        MouseArea {
            id: ma
            width: parent.width
            height: 76
            preventStealing: true
            cursorShape: Qt.SizeHorCursor
            onPressed: mk.forceActiveFocus()
            onPositionChanged: e => mk.put(mapToItem(line, e.x, 0).x / 15)
            onReleased: {
                wait.stop();
                if (mk.v !== mk.value) mk.moved(mk.v);
            }
        }
    }

    // a button: a pill with the icon in a circle. click, ↵, space
    component Act: Rectangle {
        id: act
        property string icon
        property string text
        signal hit
        width: actL.implicitWidth + 110
        height: 64
        radius: Skin.corner(32)
        color: Skin.s2
        border { width: activeFocus ? 1 : 0; color: Skin.fg }
        activeFocusOnTab: true
        Keys.onPressed: e => {
            if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space) return;
            act.hit();
            e.accepted = true;
        }
        Rectangle {
            x: 6
            y: 6
            width: 52
            height: 52
            radius: 26
            color: Skin.s3
            Icon { anchors.centerIn: parent; text: act.icon; font.pixelSize: 22 }
        }
        Lb { id: actL; x: 76; anchors.verticalCenter: parent.verticalCenter; text: act.text; color: act.activeFocus ? Skin.fg : Skin.grey }
        TapHandler { onTapped: act.hit() }
    }
}
