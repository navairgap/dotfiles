pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings
import "tones.js" as Tones

// pulse: black, white dots, one red. palette, fonts, motion, state (theme, silence) and the look of hypr/kitty live here
Singleton {
    id: root

    // state survives a restart; the lock (a separate process) reads it too
    readonly property alias state: st
    // where the color comes from (launcher → style, settings → STYLE), like caelestia's scheme: nothing — black, white and
    // red; wall — from the wallpaper tone via a variant, like caelestia's dynamic (tonal spot, fruit salad… — tones.js);
    // scheme — a ready palette with a theme of its own. a palette is { light, c: greys by the roles below, accent, red,
    // ansi: 16 kitty colors }
    readonly property var pal: make({})
    readonly property bool light: pal.light

    // light theme — same layout, greys flipped; red stays red
    readonly property var voidDark: ["#000000", "#0E0E0E", "#1A1A1A", "#2A2A2A", "#4A4A4A", "#8C8C8C", "#F2F2F2"]
    readonly property var voidLight: ["#E9E9E9", "#FFFFFF", "#F1F1F1", "#D9D9D9", "#B8B8B8", "#6E6E6E", "#0B0B0B"]
    readonly property var greys: pal.c
    readonly property color bg: greys[0]   // backdrop, wallpaper
    readonly property color s1: greys[1]   // bar, panels
    readonly property color s2: greys[2]   // tiles, off
    readonly property color s3: greys[3]   // lines, dead dots
    readonly property color mute: greys[4] // inactive
    readonly property color grey: greys[5] // labels, secondary
    readonly property color fg: greys[6]   // text, on, focus
    readonly property color ink: light ? s1 : bg // text on a white tile
    readonly property color accent: pal.accent // at most one thing on screen, and only where it's alive
    readonly property color red: pal.red       // alarm: battery, critical, wrong password
    readonly property color nothingRed: "#D71921"
    readonly property color glow: light ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrim: fade(bg, light ? 0.8 : 0.74)

    readonly property string dot: "Doto"                   // digits and short words, never below 26px
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "Space Mono"            // labels in caps
    readonly property string nf: "JetBrainsMono Nerd Font" // icons

    // layout canvas 1920×1080 → the screen. scaled by the first screen; the second runs the same layout (hypr does its
    // scale) and home just stretches the bento toward the right edge
    readonly property real s: {
        const sc = Quickshell.screens[0];
        return sc ? Math.min(sc.width / 1920, sc.height / 1080) : 1;
    }
    // per-screen settings live in state.screens keyed by monitor model: the model is the monitor, not the port (the same
    // monitor in another port or through a dock keeps its own). two identical ones or no model — the port name. the model
    // string is the one hyprctl reports (Rules.key)
    function sid(name) {
        const m = Quickshell.screens.find(s => s.name === name)?.model.trim();
        return m && Quickshell.screens.filter(s => s.model.trim() === m).length === 1 ? m : name;
    }
    // by port name — an old entry (before models) or a twin that's no longer one
    function own(name) { return st.screens[sid(name)] ?? st.screens[name]; }
    // a screen's setting by output name: its own, else shared; bar and home default to on
    function scr(name, key) { return own(name)?.[key] ?? { wall: st.wall, widgets: st.widgets }[key] ?? true; }
    // undefined removes the override, the screen falls back to shared. a port-name entry is copied under the model but
    // kept: if the twin comes back, the screen is looked up by port again
    function setScr(name, key, v) {
        const o = Object.assign({}, own(name)), all = Object.assign({}, st.screens);
        if (v === undefined) delete o[key];
        else o[key] = v;
        all[sid(name)] = o;
        st.screens = all;
    }

    // glide: ease-out-quart, no overshoot — like hypr's bezier glide
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    // the wallpaper draws from a downscaled copy (the picker makes one with magick): the original can be a 40 MB png and
    // would take seconds. no copy (cache wiped, path typed by hand) — empty, grid and orb until the picker opens
    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/pulse/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : ""; }

    // ---- wallpaper tones: up to four to pick from, like android. they live in pulse.json so the lock (separate process)
    // gets ready-made ones and doesn't flash red ----
    // the wallpaper the color comes from: the first screen's own or shared (if every screen has its own, the shared one is never seen)
    readonly property string wall: scr(Quickshell.screens[0]?.name, "wall")
    readonly property var tones: wall ? st.tones : []
    function hueName(c) {
        const h = Qt.color(c).hslHue * 360;
        return ["red", "orange", "yellow", "green", "teal", "blue", "violet", "pink", "red"][[15, 40, 65, 160, 195, 250, 290, 335, 361].findIndex(x => h < x)];
    }
    // the palette st would have with o ({ paint, scheme, at, variant, light }) swapped in: the shell runs on it (o empty),
    // and the STYLE swatches preview it. no tones (grey wallpaper, no image) — nothing
    function make(o) {
        const k = Object.assign({ paint: st.paint, scheme: st.scheme, at: st.paintAt, variant: st.variant, light: st.light }, o);
        if (k.paint === "scheme") return Tones.ALL.find(p => p.id === k.scheme) ?? Tones.ALL[0];
        // the 16 pulse ansi: in light mode 0↔15 and 7↔8 swap, so white doesn't drown in white
        const base = { light: k.light, c: k.light ? voidLight : voidDark, accent: nothingRed, red: nothingRed,
                       ansi: k.light ? [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => ansi[i]) : ansi };
        const src = tones[Math.min(k.at, tones.length - 1)];
        return k.paint === "wall" && src ? Tones.dynamic(src, k.variant, base) : base;
    }
    // theme: a palette is itself or its group-mate (mocha → latte, dawn → main); no mate (nord, dracula…) — the theme is
    // locked, else st.light would drift from the screen and resurface when the source changes
    function pair(l) { return st.paint !== "scheme" ? null : pal.light === l ? pal : Tones.ALL.find(x => x.group === pal.group && x.light === l) ?? null; }
    function setLight(l) {
        const p = pair(l);
        if (st.paint === "scheme" && !p) return;
        if (p) st.scheme = p.id;
        st.light = l;
    }
    // the picker for the launcher (style) and settings (STYLE): blocks { head, items: [{ name, pal, fill, dot, now, run }] };
    // pal — what choosing it gives, fill — the swatch circle, dot — the smaller circle inside (accent), now — currently on.
    // the source first, under it what that source offers: wallpaper tones and variants, or palettes by group; theme last
    readonly property var styles: {
        const set = (k, v) => () => st[k] = v, at = Math.min(st.paintAt, tones.length - 1);
        const it = (name, p, now, run, fill) => ({ name, pal: p, fill: fill ?? p.c[1], dot: p.accent, now, run });
        const own = st.paint === "wall" ? [
            { head: "tones", items: tones.map((t, i) => it(hueName(t), make({ at: i }), at === i, set("paintAt", i), t)) },
            // the circle is the variant's grey mute (shows where the greys ended up), accent inside; amount — how much color, in order
            { head: "variant", items: tones.length ? Tones.VARIANTS.map((v, i) => {
                const p = make({ variant: v.id });
                return Object.assign(it(v.name, p, st.variant === v.id, set("variant", v.id), p.c[4]), { amount: i / (Tones.VARIANTS.length - 1) });
            }) : [] }
        ] : st.paint === "scheme" ? Tones.GROUPS.map(g => ({ head: g, items: Tones.ALL.filter(p => p.group === g).map(p =>
            Object.assign(it(p.name, p, st.scheme === p.id, () => { st.scheme = p.id; st.light = p.light; }), { extra: g })) })) : [];
        return [{ head: "source", items: [
            it("nothing", make({ paint: "" }), !st.paint || st.paint === "wall" && !tones.length, set("paint", ""), nothingRed),
            it("wallpaper", make({ paint: "wall" }), st.paint === "wall" && !!tones.length, set("paint", "wall"), tones[0]),
            it("palette", make({ paint: "scheme" }), st.paint === "scheme", set("paint", "scheme"))
        ] }].concat(own.filter(b => b.items.length), [
            { head: "theme", items: [["dark", false], ["light", true]].map(([n, l]) => it(n, make({ light: l, scheme: pair(l)?.id ?? st.scheme }),
                light === l, () => setLight(l))) }
        ]);
    }
    // like material you's score, just simpler: the quantizer cuts the image into 16 equal-area chunks and hands over each
    // chunk's average. only the vivid ones vote (chroma — max − min channel — above 0.12; below that the big washed-out
    // fills win over the image's actual color): first the hue with the most votes (±15°), among its own the most vivid.
    // then up to three more, no closer than 30° to each other. none vivid — no tones, red stays. the quantizer calls this
    // from shell.qml (not here: the lock loads Skin too)
    function pick(cols) {
        const ch = c => c.hsvSaturation * c.hsvValue, d = (a, b) => Math.abs((a.hsvHue - b.hsvHue + 1.5) % 1 - 0.5);
        const all = Array.from(cols), live = all.filter(c => ch(c) > 0.12);
        const score = c => 0.7 * live.filter(o => d(o, c) < 1 / 24).length / all.length + 0.3 * ch(c);
        const out = [];
        for (const c of live.sort((a, b) => score(b) - score(a)))
            if (out.length < 4 && out.every(o => d(o, c) >= 1 / 12)) out.push(c);
        return out.map(c => c.toString());
    }
    // relative luminance, as in wcag
    function lum(c) { c = Qt.lighter(c, 1); const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); }
    // what to write over color c: black or white, whichever contrasts more (luminance threshold 0.18, per wcag)
    function on(c) { return lum(c) > 0.18 ? "#000000" : "#FFFFFF"; }

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    // corner radius of a panel, tile, pill — from the corners setting (prefs → WINDOWS → panels): 0 square, 100 as designed
    function corner(px) { return px * st.corners / 100; }
    // clock per the 12/24 setting: "09" or "9"
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    readonly property string riceState: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice"
    // like Rules: apply() at startup has to see pulse.json, not defaults
    Component.onCompleted: stateFile.waitForJob()

    FileView {
        id: stateFile
        path: root.riceState + "/pulse.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // write once per turn: writeAdapter() per field in a row garbles its neighbors
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property string paint: ""     // where the color comes from: "" nothing, wall wallpaper, scheme palette
            property string scheme: "mocha" // which palette, id from tones.js
            property int paintAt: 0       // which of the wallpaper tones
            property var tones: []        // wallpaper tones, the quantizer writes them; empty — grey wallpaper or no image
            property string variant: "tonalspot" // how a wallpaper tone becomes a palette, id from tones.js (VARIANTS)
            property bool dnd: false  // ordinary ones hidden, critical always through
            property int unread: 0    // for the lock
            // ---- what the settings (prefs) turn ----
            property var widgets: ["weather", "calendar", "cpu", "player", "buds", "system"] // home bento in order, see kinds
            property bool clock24: true
            property bool blink: true      // the clock colon blinks
            property string name: ""       // in the greeting; empty — $USER
            property bool grid: true       // dot grid over the wallpaper
            property bool orb: true        // halftone orb
            // the wallpaper (wall/Walls picker, components/Wall draws it): path to the image; empty — grid and orb.
            // the picker folder can be changed here
            property string wall: ""
            property string wallDir: ""    // empty — ~/Pictures/Wallpapers
            property int wallLook: 0       // 0 dots, 1 grey photo, 2 color
            property int wallPitch: 10     // dot pitch, px
            property int wallBright: 85    // %, from background to picture
            property string gif: ""        // the cat tile gif (services/Gifs), path; empty — first in the folder
            property string gifDir: ""     // empty — ~/Pictures/Gifs
            property int rounding: 20      // hypr windows
            property int corners: 100      // shell panel corners, % of their own; circles stay circles (Skin.corner)
            property bool edges: true      // edge light strips (volume/brightness, flashes, progress)
            property int briSteps: 20      // brightness keys: ticks on the scale, 40/20/10 — steps of 2.5/5/10 %
            property bool quickHover: true // quick settings on hover at the right edge
            property bool deckHover: true  // deck — the bottom-center panel, slides out on edge hover
            property var deck: ["clock", "weather", "perf", "net", "media"] // its sections in order, see decks
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"] // bar tray top to bottom, see bars
            property bool barTitle: true   // window title as a column in the bar
            property string barAt: "left" // left or top; the calendar, battery card, home, island and pulse flash all ride behind the bar
            // per-monitor by model (Skin.sid): { "TS2700-S6-1": { bar: false, home: false, wall: "…", widgets: […] } }; missing — shared (Skin.scr)
            property var screens: ({})
            // recording (quick/Rec, Sys.recArgs)
            property int recArea: 0        // 0 whole monitor, 1 region (slurp)
            property int recAudio: 0       // 0 silent, 1 system, 2 mic, 3 both on one track
            property int recFps: 60
            property int recQuality: 2     // medium, high, very_high, ultra
            property bool recCursor: true
            property bool vpnPortal: false // tunnel dropped by the portal, restore once on an open network (vpn/Vpn)
        }
    }

    // bento widgets: id → width in cells (grid 3 columns × 3 rows of 220). what doesn't fit isn't shown
    readonly property var kinds: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, gpu: 1, disk: 1, battery: 1, buds: 1, player: 2, system: 3, cat: 1, cava: 1 })
    // deck sections
    readonly property var decks: ["clock", "weather", "perf", "net", "media"]
    // the bar tray
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power", "cat"]

    // ---- the look of everything outside the shell. only shell.qml calls it: at startup, on theme or color change ----
    // monitor, input, idle, night light and motion come from Rules (shell.qml); animations stay wherever the hypr config
    // has them. from here — gaps/border/blur/shadows out of rules.json, plus mine: border, shadow and group colors,
    // background, rounding 20 (without them the red glow and groups from hypr/variables.lua would leak through).
    // `rice switch` to another shell runs hyprctl reload, and its applyAll repaints
    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // kitty includes this file after its colors (include in kitty.conf); whichever shell is live writes its palette there
    FileView { id: kitty; path: Quickshell.env("HOME") + "/.config/pulse/kitty.conf"; printErrors: false }
    // the 16 ansi from the concept: pastel stays in the terminal. the light theme reshuffles them (make)
    readonly property var ansi: ["#0E0E0E", "#D71921", "#9BB59A", "#D9C38A", "#8EA3C2", "#B79BC2", "#8FB8B8", "#C9C9C9",
                                 "#4A4A4A", "#F0434B", "#B5CCB4", "#E8D6A8", "#AABBD4", "#CDB6D6", "#ABCDCD", "#F2F2F2"]

    function apply() {
        // game mode (Rules.store.game) sits over the settings like ultra: border 1, no gaps, no rounding, tearing for
        // immediate windows (games, hyprland/rules.lua). leave it and my values return, allow_tearing back to false like general.lua
        const r = Rules.store, g = r.game;
        const c = x => `"rgb(${hex(x)})"`;
        // shadow: a barely-there white glow in the dark theme, a soft black one in light
        const shadow = light ? "rgba(0000002E)" : `rgba(${hex(fg)}1A)`;
        hypr(`hl.config({ general = { gaps_in = ${g ? 0 : r.gapsIn}, gaps_out = ${g ? 0 : r.gapsOut}, border_size = ${g ? 1 : r.border}, allow_tearing = ${g}, `
           + `col = { active_border = ${c(fg)}, inactive_border = ${c(s3)} } }, `
           + `decoration = { rounding = ${g ? 0 : st.rounding}, blur = { enabled = ${Rules.blurOn} }, shadow = { enabled = ${Rules.shadowOn}, color = "${shadow}" } }, `
           + `group = { col = { border_active = ${c(fg)}, border_inactive = ${c(s3)}, border_locked_active = ${c(fg)}, border_locked_inactive = ${c(mute)} }, `
           + `groupbar = { font_family = "${mono}", text_color = ${c(fg)}, col = { active = ${c(s3)}, inactive = ${c(s1)}, locked_active = ${c(s3)}, locked_inactive = ${c(s1)} } } }, `
           + `misc = { background_color = ${c(bg)} } })`);

        kitty.setText("# pulse: written by Skin.apply(), don't edit by hand\n" + [
            ["font_family", "Space Mono"], ["window_padding_width", "26 30"], ["cursor_trail", "0"],
            ["foreground", fg], ["background", s1], ["cursor", fg], ["cursor_text_color", s1],
            ["selection_foreground", fg], ["selection_background", s3], ["url_color", grey],
            ["active_border_color", fg], ["inactive_border_color", s3],
            ["active_tab_foreground", ink], ["active_tab_background", fg],
            ["inactive_tab_foreground", grey], ["inactive_tab_background", s1], ["tab_bar_background", bg]
        ].concat(pal.ansi.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
    }

    // gtk and qt — only on a color change (shell.qml): apply() also runs on every step of the rounding ring. the templates
    // are my term/ (pulse's dark palette): their colors get swapped for the same roles in the palette (greys, red, and for
    // qt green/yellow/blue… from ansi), copies land in riceState/pulse, the ~/.config/… links point at the copies.
    // nothing to swap — back to term/, the way rice sets it. real files (not links) are left alone, like rice. the swap
    // goes in two passes through @n@: a palette color can equal a pulse color that gets replaced right after. gtk and qt
    // pick the colors up on their next start: gtk reads its gtk.css once, poking the theme doesn't help (checked on gtk 3 and 4).
    // light stays dark here — the gtk base is dark (adw-gtk3-dark): wallpapers get the same variant dark, palettes their
    // dark mate (latte → mocha), nothing gets pulse; a real light theme would also want gtk-theme and color-scheme.
    // btop stays unpainted — its folder is symlinked into the repo whole, nowhere to put a copy; if ever needed,
    // color_theme with a path to one
    function apps() {
        const from = voidDark.concat(ansi.slice(1, 7));
        const p = pal.light ? pair(false) ?? make({ light: false }) : pal;
        const to = p.c.concat([p.red], p.ansi.slice(2, 7));
        const pairs = from.map((c, i) => [c, "#" + hex(Qt.lighter(to[i], 1))]).filter(([a, b]) => a !== b);
        const sed = pairs.map(([a], i) => ["-e", `s/${a}/@${i}@/gI`]).concat(pairs.map(([, b], i) => ["-e", `s/@${i}@/${b}/g`])).reduce((x, y) => x.concat(y), []);
        Quickshell.execDetached(["bash", "-c", `t=$1 o=$2; shift 2
for f in gtk-3.0/gtk.css gtk-4.0/gtk.css qtengine.colors; do
    l=$HOME/.config/$f
    [ -L "$l" ] || [ ! -e "$l" ] || continue
    if [ $# -gt 0 ]; then mkdir -p "$(dirname "$o/$f")" && sed "$@" "$t/$f" > "$o/$f" && ln -sfn "$o/$f" "$l"; else ln -sfn "$t/$f" "$l"; fi
done`,
            "bash", Quickshell.shellPath("term"), riceState + "/pulse"].concat(sed));
    }
}
