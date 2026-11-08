import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// launcher: super tap or super+space. an 860 panel dead center, the screen dims to 74%. pill search with a red caret,
// modes as chips (tab): apps / style / windows / calc. no query — "recent" plus every app in a grid of 6, alphabet rail on the right.
// style is where my color comes from: the source (nothing, wallpaper, palette), under it wallpaper tones and variants (tonal spot…)
// or palettes (catppuccin, rosé pine…) — the theme list is Skin.styles, the same one STYLE in settings uses. circles are swatches,
// the dot marks what's live, ↵ applies and keeps the launcher open. with palettes the search matches group names too: "catppuccin".
// opens like the rest of my panels: 24 up and a fade. icons are the theme's dots inside circles; the selected one is a white disc
PanelWindow {
    id: root

    property int mode: 0
    property int sel: 0
    readonly property var modes: ["apps", "style", "windows", "calc"]
    readonly property string query: input.text
    property var uses: ({}) // app id → how many times i opened it

    // theme icon or the .desktop path; no icon (or no such file) — the generic app icon, not an empty circle
    function icon(name) { return Quickshell.iconPath(name || "application-x-executable", "application-x-executable"); }

    // desktop entries land one by one at startup (~160 valuesChanged): a binding would rebuild the grid for each —
    // seconds of freeze. i collect once, after the list settles
    property var apps: []
    Timer {
        id: appsT
        interval: 300
        running: true
        onTriggered: root.apps = DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
            id: e.id, name: e.name, src: root.icon(e.icon),
            extra: `${e.id} ${e.genericName} ${(e.keywords ?? []).join(" ")}`.toLowerCase(), run: () => e.execute()
        })).sort((a, b) => a.name.localeCompare(b.name))
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { appsT.restart(); }
    }
    // windows only while the windows mode is open: otherwise every title change would rebuild the list
    readonly property var wins: !visible || mode !== 2 ? [] : Hyprland.toplevels.values.map(t => {
        const cls = t.lastIpcObject?.class ?? "";
        return { name: t.title, src: icon(DesktopEntries.heuristicLookup(cls)?.icon), extra: cls.toLowerCase(),
                 run: () => { focusT.addr = t.address; focusT.restart(); } };
    })
    // while the launcher holds the keyboard (exclusive) hyprland will switch workspaces but won't focus a window — and on
    // release it brings the old window back with its workspace. so i focus on release (fires with the next frame).
    // 100ms is slack for a frame; if it ever races, focus from onVisibleChanged instead, after the fade
    Timer {
        id: focusT
        property string addr
        interval: 100
        onTriggered: Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${addr}" })`) // quickshell hands out the address without 0x
    }

    // subsequence match: a word start and a run score higher. hl — indexes of the matched letters
    function match(s, q) {
        if (!q) return { score: 1, hl: [] };
        const l = s.toLowerCase(), hl = [], at = l.indexOf(q);
        if (at >= 0) { for (let k = 0; k < q.length; k++) hl.push(at + k); return { score: (at === 0 ? 100 : 50) - at, hl }; }
        let i = 0;
        for (const c of q) {
            i = l.indexOf(c, i);
            if (i < 0) return null;
            hl.push(i++);
        }
        return { score: 10, hl };
    }
    function filter(src, q) {
        const out = [];
        for (const it of src) {
            const m = match(it.name, q);
            if (m) out.push(Object.assign({}, it, { hl: m.hl, score: m.score }));
            else if (it.extra.includes(q)) out.push(Object.assign({}, it, { hl: [], score: 1 }));
        }
        return out.sort((a, b) => b.score - a.score || (uses[b.id] ?? 0) - (uses[a.id] ?? 0));
    }

    // blocks: { head, sub, items }; every cell gets a row/col and the arrows walk them
    readonly property var blocks: {
        const q = query.trim().toLowerCase();
        let b;
        if (mode === 1) b = Skin.styles.map(x => ({ head: x.head, items: filter(x.items.map(it => Object.assign({ extra: "", keep: true }, it)), q) })).filter(x => x.items.length);
        else if (mode === 3) b = [];
        else if (mode === 2) b = [{ head: "windows", sub: String(wins.length), items: filter(wins, q) }];
        else if (q) {
            const r = filter(apps, q);
            b = [{ head: "results", sub: String(r.length), items: r }];
        } else {
            const recent = apps.filter(a => uses[a.id]).sort((a, b) => uses[b.id] - uses[a.id]).slice(0, 6);
            b = (recent.length ? [{ head: "recent", items: recent }] : []).concat([{ head: "all apps", sub: String(apps.length), all: true, items: apps }]);
        }
        let row = 0, k = 0;
        for (const x of b) {
            x.items = x.items.map((it, i) => Object.assign({}, it, { row: row + Math.floor(i / 6), col: i % 6, k: k++ }));
            row += Math.ceil(x.items.length / 6);
        }
        return b;
    }
    readonly property var flat: blocks.reduce((a, x) => a.concat(x.items), [])
    readonly property var cur: flat[sel] ?? null

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }

    function open() {
        focusT.stop(); // a window queued by the last open must not steal focus from this one
        input.text = "";
        mode = 0;
        sel = 0;
        flick.contentY = 0;
        shown = true;
        input.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function move(dr, dc) {
        if (!flat.length) return;
        if (dc) return sel = (sel + dc + flat.length) % flat.length;
        const c = cur, row = flat.filter(x => x.row === c.row + dr);
        if (row.length) sel = row.reduce((a, x) => Math.abs(x.col - c.col) < Math.abs(a.col - c.col) ? x : a).k;
    }
    function launch() {
        if (!shown) return; // still fading under Skin.t and still catching clicks: the second click of a double would open another window
        if (mode === 3) {
            if (calcOut) Quickshell.execDetached(["wl-copy", calcOut]);
            return close();
        }
        const it = cur;
        if (!it) return;
        if (it.keep) return it.run();
        close();
        if (it.id) {
            uses = Object.assign({}, uses, { [it.id]: (uses[it.id] ?? 0) + 1 });
            usesFile.setText(JSON.stringify(uses));
        }
        it.run();
    }

    FileView {
        id: usesFile
        path: Quickshell.statePath("launcher-uses.json")
        printErrors: false
        onLoaded: try { root.uses = JSON.parse(text()); } catch (e) {}
    }

    property string calcOut: ""
    Process { id: calc; stdout: StdioCollector { onStreamFinished: root.calcOut = text.trim() } }
    onQueryChanged: {
        sel = 0;
        if (mode === 3 && query.trim()) calc.exec(["qalc", "-t", query]); // exec kills the previous run
        else calcOut = "";
    }
    onModeChanged: { sel = 0; flick.contentY = 0; if (mode === 3) queryChanged(); }
    // the list shrank without a new query (a window closed in windows mode) — the cursor would sit past the end, cur empty
    onFlatChanged: sel = Math.max(0, Math.min(sel, flat.length - 1))

    onVisibleChanged: if (visible) input.forceActiveFocus()

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-launcher"

    Rectangle {
        anchors.fill: parent
        color: Skin.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: 140 + 24 * (1 - root.t)
            width: 860
            height: Math.min(stage.height - 280, 30 + 66 + 20 + body.height + 34)
            opacity: root.t
            radius: Skin.corner(44)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
            MouseArea { anchors.fill: parent }

            // search: the pill, the red caret, the mode chips
            Rectangle {
                id: search
                x: 34
                y: 30
                width: parent.width - 68
                height: 66
                radius: Skin.corner(33)
                color: Skin.s2

                Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Skin.grey; font.pixelSize: 22 }
                TextInput {
                    id: input
                    anchors { left: lens.right; leftMargin: 16; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font { family: Skin.ui; pixelSize: 22 }
                    color: Skin.fg
                    selectionColor: Skin.s3
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Skin.accent
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text {
                        visible: !input.text
                        x: 6
                        text: ["Search apps", "Color from nothing, the wallpaper or a palette", "Find a window", "2 + 2, 20 usd to eur…"][root.mode]
                        font: input.font
                        color: Skin.mute
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch();
                        else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                        else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                        else if (e.key === Qt.Key_Down) root.move(1, 0);
                        else if (e.key === Qt.Key_Up) root.move(-1, 0);
                        else if (e.key === Qt.Key_Right && (!input.text || input.cursorPosition === input.text.length) && root.flat.length) root.move(0, 1);
                        else if (e.key === Qt.Key_Left && (!input.text || input.cursorPosition === 0) && root.flat.length) root.move(0, -1);
                        else return;
                        e.accepted = true;
                    }
                }
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: root.modes
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: chip.width + 32
                            height: chip.height + 20
                            radius: height / 2
                            color: root.mode === index ? Skin.fg : "transparent"
                            Lb { id: chip; anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.mode === parent.index ? Skin.ink : Skin.grey }
                            TapHandler { onTapped: { root.mode = parent.index; input.forceActiveFocus(); } }
                        }
                    }
                }
            }

            Flickable {
                id: flick
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: parent.bottom; topMargin: 20; leftMargin: 34; rightMargin: 34; bottomMargin: 34 }
                contentHeight: body.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function ensure(y, h) {
                    if (y < contentY) contentY = Math.max(0, y);
                    else if (y + h > contentY + height) contentY = y + h - height;
                }

                Column {
                    id: body
                    width: flick.width

                    // calc: the answer big, enter copies it
                    Column {
                        visible: root.mode === 3
                        topPadding: 10
                        spacing: 10
                        Lb { text: root.calcOut ? "↵ copy" : "qalc" }
                        Num { width: body.width; elide: Text.ElideRight; text: root.calcOut || "—"; font.pixelSize: 96 }
                    }

                    // keyed by index, not by array: fresh blocks (a typed letter, a launch, recent) don't rebuild ~160 cells
                    // with icons and layers — those just get new data
                    Repeater {
                        id: blockRep
                        model: root.blocks.length

                        Column {
                            id: block
                            required property int index
                            readonly property var modelData: root.blocks[index] ?? ({ head: "", items: [] })
                            readonly property Item g: grid
                            width: body.width
                            topPadding: index ? 30 : 10 // flick adds 20 above: scrolled content cuts off with a gap under the search

                            Row {
                                spacing: 14
                                bottomPadding: 18
                                // doto group letter: which letters are on screen right now
                                Num { visible: !!block.modelData.all; anchors.baseline: blab.baseline; text: root.range; font.pixelSize: 34 }
                                Lb { id: blab; text: block.modelData.head + (block.modelData.sub ? ` · ${block.modelData.sub}` : "") }
                            }
                            Grid {
                                id: grid
                                columns: 6
                                rowSpacing: 22
                                Repeater {
                                    model: block.modelData.items.length
                                    Cell { items: block.modelData.items; gy: block.y + grid.y }
                                }
                            }
                        }
                    }
                }
            }

            // alphabet rail: letters on screen are white, a tap jumps to the first app with that letter
            Column {
                visible: root.mode === 0 && !root.query && !!root.allGrid
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 130 }
                spacing: 3
                Repeater {
                    model: [..."ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
                    Text {
                        required property string modelData
                        width: 12
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font { family: Skin.mono; pixelSize: 10 }
                        color: root.range.includes(modelData) ? Skin.fg : Skin.mute
                        TapHandler { onTapped: root.jump(parent.modelData) }
                    }
                }
            }
        }
    }

    // letters of every app whose rows are visible right now: "A–F"
    readonly property var allItems: blocks.find(b => b.all)?.items ?? []
    readonly property Item allGrid: { const i = blocks.findIndex(b => b.all); return blockRep.count > i && i >= 0 ? blockRep.itemAt(i)?.g ?? null : null; }
    readonly property string range: {
        if (!allGrid || !allItems.length) return "";
        const top = allGrid.mapToItem(body, 0, 0).y, rh = 88 + 10 + 20 + 22; // disc, padding, label, gap
        const r0 = Math.max(0, Math.floor((flick.contentY - top) / rh)), r1 = Math.floor((flick.contentY + flick.height - top) / rh);
        const seen = allItems.slice(r0 * 6, (r1 + 1) * 6).map(a => a.name[0].toUpperCase());
        return seen.length ? seen[0] === seen[seen.length - 1] ? seen[0] : `${seen[0]}–${seen[seen.length - 1]}` : "";
    }
    function jump(l) {
        const i = allItems.findIndex(a => a.name[0].toUpperCase() >= l);
        if (i < 0) return;
        sel = allItems[i].k;
        flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), allGrid.mapToItem(body, 0, 0).y + Math.floor(i / 6) * (88 + 10 + 20 + 22));
    }

    // app cell: an 88 disc with the icon dotted on top, label keeps the matched letters white
    component Cell: Column {
        id: cell
        required property int index
        property var items: []
        readonly property var modelData: items[index] ?? ({ name: "", hl: [] })
        readonly property bool on: root.sel === modelData.k
        // quickshell rebuilds the layer-shell window on every open, and Image loads its texture even hidden: 160 icons is
        // ~60ms off the first frame. outside the scroll (a row of slack included) the cell stays empty and icon-less, it holds its own height
        property real gy // the grid's y within body
        readonly property bool near: gy + y < flick.contentY + flick.height + 140 && gy + y + height > flick.contentY - 140
        width: body.width / 6
        height: 88 + spacing + label.implicitHeight
        spacing: 10
        onOnChanged: if (on) flick.ensure(mapToItem(body, 0, 0).y - 8, height + 8) // 8 — the swatch ring pokes out over the disc

        Rectangle {
            id: disc
            visible: cell.near
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88
            height: 88
            radius: 44
            color: cell.modelData.fill ?? (cell.on ? Skin.fg : Skin.s2)
            border { width: cell.modelData.fill ? 1 : 0; color: Skin.s3 } // a dark swatch still reads against the panel
            // a hovered swatch gets a ring — filling it white would swallow the color. dot is the palette accent, the live one gets a dot
            Rectangle { visible: cell.on && !!cell.modelData.fill; anchors.centerIn: parent; width: 104; height: 104; radius: 52; color: "transparent"; border { width: 2; color: Skin.fg } }
            Rectangle { id: inner; visible: !!cell.modelData.dot; anchors.centerIn: parent; width: 40; height: 40; radius: 20; color: cell.modelData.dot ?? "transparent" }
            Rectangle { visible: !!cell.modelData.now; anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: Skin.on(inner.visible ? inner.color : disc.color) }
            Image {
                anchors.centerIn: parent
                visible: status === Image.Ready
                width: 44
                height: 44
                source: cell.near ? cell.modelData.src ?? "" : ""
                sourceSize: Qt.size(44, 44)
                asynchronous: true
                retainWhileLoading: true // the cell got another app — keep the old icon until the new one lands
                layer.enabled: cell.near // the layer draws its image even when hidden
                layer.effect: Dm { step: 2.5 }
            }
            TapHandler { onTapped: { root.sel = cell.modelData.k; root.launch(); } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        Text {
            id: label
            visible: cell.near
            width: parent.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            readonly property var hl: cell.modelData.hl ?? []
            text: [...cell.modelData.name].map((c, i) => {
                const e = c === "<" ? "&lt;" : c === "&" ? "&amp;" : c;
                return hl.includes(i) ? `<font color="${Skin.fg}">${e}</font>` : e;
            }).join("")
            font { family: Skin.ui; pixelSize: 14 }
            color: cell.on ? Skin.fg : Skin.grey
        }
    }
}
