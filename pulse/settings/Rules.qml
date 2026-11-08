pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// house rules: ~/.config/pulse/rules.json is the single source of truth for the settings.
// an edit from settings writes the file (writeAdapter) and runs the matching apply itself. only shell.qml calls applyAll,
// at startup: the lock (lock.qml) reads Skin → Rules too, but applies nothing
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/pulse"
    readonly property alias store: adapter

    // eight colors in Skin order: void crypt wine plum rose crimson ash bone
    readonly property var palettes: [
        { name: "Demon's Shot", what: "blood & bone", c: ["#0D0B0E", "#151116", "#2B1820", "#4A2236", "#B8487A", "#C7303D", "#7A6870", "#E9DFDD"] },
        { name: "Absinthe", what: "green fairy", c: ["#0B0D0B", "#121612", "#1E2A1F", "#2F4630", "#A9B85A", "#7CC24A", "#6E7A6C", "#E3E6D8"] },
        { name: "Nightshade", what: "poison bloom", c: ["#0C0B10", "#131119", "#221A30", "#3A2852", "#8E6BD8", "#B04BD6", "#706A80", "#E4DFEA"] },
        { name: "Holy Water", what: "cold blessing", c: ["#0A0C10", "#11151B", "#1A2433", "#263C57", "#5E9BD1", "#3F7FE0", "#687687", "#DDE4EA"] },
        { name: "Rust", what: "old iron", c: ["#0E0B09", "#17120F", "#2E1D14", "#4D2E1C", "#D08A3E", "#D1532A", "#7E6E62", "#EADFD3"] },
        { name: "Gilded", what: "altar gold", c: ["#0D0C0A", "#16140F", "#2E2716", "#4A3D1E", "#B88A4A", "#D9A43A", "#7A7262", "#EDE5D3"] },
        { name: "Ghost", what: "no color left", c: ["#0C0C0D", "#141416", "#26262A", "#3A3A40", "#9A9AA6", "#E9E9EE", "#6E6E76", "#E2E2E6"] }
    ]
    readonly property var pal: palettes[adapter.palette] ?? palettes[0]

    // wait for the file while the singleton builds: otherwise the first store reader (pulse at startup) gets defaults instead of rules.json
    Component.onCompleted: file.waitForJob()

    FileView {
        id: file
        path: root.dir + "/rules.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: this.reload()
        // write once per turn: writeAdapter() per field in a row garbles its neighbors (a preset changes four at once)
        onAdapterUpdated: Qt.callLater(file.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) this.writeAdapter(); } // first run: write the defaults out

        // defaults match the hypr config as it stands, so the first run moves nothing
        JsonAdapter {
            id: adapter
            // Display
            property real monScale: 0      // 0 — auto, hypr decides
            property int refresh: 0        // 0 — the screen's highest hz, like mode = "highres" in hyprland.lua
            property string main: ""       // whose monScale and refresh (Rules.mon); empty — the first monitor read decides
            // the other screens, if prefs touched them, keyed by Rules.key: { "TS2700-S6-1": { scale: 1, refresh: 144, pos: [-560, -1440] } };
            // pos relative to the main one, which then sits at 0x0
            property var outs: ({})
            property int brightness: 62
            property bool night: false
            property int warmth: 4300
            property int gapsIn: 6
            property int gapsOut: 14
            property int border: 2
            property int rounding: 0
            property bool blur: true
            property bool shadow: true
            property bool motion: true
            property bool ultra: false   // ultra mode (setMode 0): 60 hz and no decoration, layered over the settings
            property bool game: false    // game mode, like caelestia's: no animations, blur, shadows, gaps or rounding, tearing (Skin.apply)
            // Colors
            property int palette: 0
            property bool paintHypr: true
            property bool paintKitty: true
            // Input — like hyprland/input.lua
            property int kbSwitch: 0      // index into switches
            property int repeatDelay: 250
            property int repeatRate: 35
            property bool natural: true
            property bool tap: true
            property bool typingOff: false
            property int scroll: 30       // % — scroll_factor 0.3
            property int sens: 0          // -100…100 → sensitivity -1…1
            property bool flat: false
            // Idle: minutes, 0 — never
            property int lockAfter: 3
            property int dpmsAfter: 5
            property int sleepAfter: 10
            property bool hibernate: true // suspend-then-hibernate
            // System
            property bool roman: true
            // Notices. silence (the ward toggle sets it too): ordinary notifications stay hidden, critical always through
            property bool dnd: false
            property int noteTime: 6      // s when the app set none of its own; 0 — wait until swiped away
            property int noteDeck: 5      // how many show in the deck
        }
    }

    // kitty: the include file with palette colors (kitty.conf pulls it in); SIGUSR1 makes kitty reread its config
    FileView { id: kitty; path: root.dir + "/kitty.conf"; printErrors: false }

    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // monitors from hyprctl monitors all — enabled, not mirrors: w × h and rates are the current mode and its refresh
    // rates, x, y, lw × lh — where it sits and its logical px (swapped around when rotated)
    property var mons: []
    // the main screen — monScale and refresh apply to it: the built-in panel, even when off (lid closed in a dock), else
    // the first one. remembered in store.main by model (port when there is none): on a desktop the screen order shifts as
    // things plug in, and a cable moving to another port or dock must not hand the scale to a different screen. an older
    // store.main holds a port name — look for that too
    property string first: ""
    readonly property var mon: mons.find(m => m.name === (store.main || first)) ?? mons.find(m => m.model && m.model === (store.main || first))
        ?? { name: "", w: 0, h: 0, x: 0, y: 0, lw: 0, lh: 0, transform: 0, scale: 1, hz: 0, rates: [] }
    property bool monWanted: false // monitor() ran before the hyprctl answer landed
    property bool driving: false   // this process drives the monitors (shell.qml called monitor()); the lock only reads
    Process {
        id: monProc
        running: true
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = JSON.parse(text);
                const f = all.find(m => /^(eDP|LVDS|DSI)/.test(m.name)) ?? all.find(m => !m.disabled);
                root.first = f ? f.model.trim() || f.name : "";
                root.mons = all.filter(m => !m.disabled && m.mirrorOf === "none").map(m => {
                    const rates = [...new Set(m.availableModes.map(s => /(\d+)x(\d+)@([\d.]+)/.exec(s))
                        .filter(r => r && +r[1] === m.width && +r[2] === m.height).map(r => Math.round(+r[3])))].sort((a, b) => a - b);
                    const t = m.transform % 2, lw = Math.round(m.width / m.scale), lh = Math.round(m.height / m.scale);
                    return { name: m.name, model: m.model.trim(), desc: m.description, w: m.width, h: m.height, x: m.x, y: m.y, lw: t ? lh : lw, lh: t ? lw : lh,
                             transform: m.transform, scale: m.scale, hz: Math.round(m.refreshRate), rates: rates.length ? rates : [Math.round(m.refreshRate)] };
                });
                if (root.monWanted) root.monitor();
                else root.settle();
            }
        }
    }
    // auto — hypr picks the scale; reread the monitors to learn what it chose
    Timer { id: monReread; interval: 500; onTriggered: monProc.running = true }
    // how a screen is written into outs: by model — the model is the monitor, not the port (a projector in the same hdmi
    // must not inherit the home screen's place and hz; the home screen in another port keeps its own); two identical ones
    // or no model — by port name. same as Skin.sid
    function key(m) { return m.model && mons.filter(x => x.model === m.model).length === 1 ? m.model : m.name; }
    // a screen's own settings; by port name — the entry of a twin that's no longer one (the key became the model)
    function out(m) { return store.outs[key(m)] ?? store.outs[m.name]; }
    // what a screen has picked: scale (0 — auto) and refresh
    function want(m) {
        if (m.name === mon.name) return { scale: store.monScale, refresh: refreshHz };
        const o = out(m);
        return { scale: o?.scale ?? m.scale, refresh: o?.refresh ?? m.hz };
    }
    // a hypr rule for the screen. it replaces the config's rule wholesale — mode (current resolution) and transform are
    // carried as-is. externals sit by pos off the main one, which then takes 0x0: on auto hypr would place it to the
    // right of the explicit ones. the selector follows key(): desc: of the monitor, not the port — the rule lives in hypr
    // until a reload, and a projector in the same port would otherwise inherit this screen's place and mode.
    // note: the shell's rule drops vrr, 10-bit and hdr from user.lua; wanted again — carry them from hyprctl like transform
    function rule(m) {
        const own = m.name === mon.name, w = want(m), pos = out(m)?.pos;
        const at = own ? (mons.some(x => x.name !== m.name && out(x)?.pos) ? "0x0" : "auto") : pos ? `${pos[0]}x${pos[1]}` : "auto";
        const output = key(m) !== m.name && m.desc ? `desc:${m.desc}` : m.name;
        return `hl.monitor({ output = ${JSON.stringify(output)}, mode = "${m.w}x${m.h}@${own ? hz : w.refresh}", position = "${at}", `
             + `scale = ${w.scale || '"auto"'}, transform = ${m.transform} })`;
    }
    // the main one and the outs externals in a single eval, main first: the rest position off it. fresh — reread first
    // (a screen was plugged in): a burst of screensChanged collapses into one read after 500 ms, and the answer already
    // has the new screen. only shell.qml calls this
    function monitor(fresh) {
        driving = true;
        if (fresh || !mons.length) {
            monWanted = true;
            if (fresh) monReread.restart();
            return;
        }
        monWanted = false;
        if (!store.main && first) store.main = first;
        const ms = mons.filter(m => m.name === mon.name || out(m)).sort((a, b) => (b.name === mon.name) - (a.name === mon.name));
        if (ms.length) hypr(ms.map(rule).join("\n"));
        monReread.restart();
    }
    // prefs → display: scale (0 — auto) or refresh of screen name. the main one gets monScale and refresh, an external
    // goes into outs (place). a scale change resizes — settle fixes the edge against the neighbor after the read
    function set(name, k, v) {
        const m = mons.find(x => x.name === name);
        if (!m) return;
        if (m.name !== mon.name) return place(name, m.x, m.y, { [k]: v });
        store[k === "scale" ? "monScale" : "refresh"] = v;
        monitor();
    }
    // put screen name at x, y (logical hypr px), extra — its fields in outs. every external gets pinned with an explicit
    // pos off the main one, right where it stands: a rule without a position and hypr would auto-place it, dragging the
    // neighbors along
    function place(name, x, y, extra) {
        const b = name === mon.name ? { x, y } : mon, o = Object.assign({}, store.outs);
        for (const m of mons) {
            if (m.name === mon.name) continue;
            const p = m.name === name ? { x, y } : m;
            // the port-name entry is kept: if the twin returns, the screen is found by port again
            o[key(m)] = Object.assign({}, out(m), m.name === name ? extra : null, { pos: [p.x - b.x, p.y - b.y] });
        }
        store.outs = o;
        monitor();
    }
    // prefs → display "reset": forget the externals' places, scales and hz — back to the hypr config (user.lua). the
    // shell's rules stay in hypr until the config is reread — so ask for exactly that; configreloaded (shell.qml) brings the rest
    function forget() {
        store.outs = {};
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    function hits(a, b) { return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h; }
    // where screen r ({ x, y, w, h }, logical hypr px) would land if dropped there: flush against a neighbor's side, no
    // overlap, shared edge at least a quarter of the smaller of the two; along that edge — where it was dropped, but it
    // snaps to the neighbor's edges and center within near. of all such spots the closest one; none — null
    function dock(r, others, near) {
        const stick = (v, lo, hi, to) => {
            v = Math.max(lo, Math.min(hi, v));
            return to.find(t => Math.abs(t - v) < near) ?? v;
        };
        let best = null, bd = Infinity;
        for (const o of others) {
            const kx = Math.min(r.w, o.w) / 4, ky = Math.min(r.h, o.h) / 4;
            const x = stick(r.x, o.x - r.w + kx, o.x + o.w - kx, [o.x, o.x + o.w - r.w, o.x + (o.w - r.w) / 2]);
            const y = stick(r.y, o.y - r.h + ky, o.y + o.h - ky, [o.y, o.y + o.h - r.h, o.y + (o.h - r.h) / 2]);
            for (const c of [{ x: o.x - r.w, y }, { x: o.x + o.w, y }, { x, y: o.y - r.h }, { x, y: o.y + o.h }]) {
                const p = { x: Math.round(c.x), y: Math.round(c.y), w: r.w, h: r.h }, d = Math.hypot(p.x - r.x, p.y - r.y);
                if (d < bd && !others.some(q => hits(p, q))) {
                    best = p;
                    bd = d;
                }
            }
        }
        return best;
    }
    // an external with an explicit pos ended up overlapping or floating (scale changed, a screen came back, a neighbor
    // was dragged away) — to the nearest free edge, one per read. already asked for that spot and hypr didn't place it —
    // don't insist, or it loops every half second. the 2 px tolerance covers rounding of the logical sizes
    function settle() {
        if (!driving || mons.length < 2) return;
        const box = m => ({ x: m.x, y: m.y, w: m.lw, h: m.lh }), near = (a, b) => Math.abs(a - b) <= 2;
        const touch = (a, b) => (near(a.x + a.w, b.x) || near(b.x + b.w, a.x)) && a.y < b.y + b.h && b.y < a.y + a.h
                             || (near(a.y + a.h, b.y) || near(b.y + b.h, a.y)) && a.x < b.x + b.w && b.x < a.x + a.w;
        for (const m of mons) {
            const pos = out(m)?.pos;
            if (m.name === mon.name || !pos) continue;
            const r = box(m), rest = mons.filter(x => x !== m).map(box);
            if (!rest.some(o => hits({ x: r.x + 2, y: r.y + 2, w: r.w - 4, h: r.h - 4 }, o)) && rest.some(o => touch(r, o))) continue;
            const d = dock(r, rest, 0);
            if (d && (d.x - mon.x !== pos[0] || d.y - mon.y !== pos[1])) return place(m.name, d.x, d.y);
        }
    }
    readonly property var rates: mon.rates.length ? mon.rates : [60, 120]
    readonly property int refreshHz: store.refresh ? rates.reduce((a, b) => Math.abs(b - store.refresh) < Math.abs(a - store.refresh) ? b : a) : rates[rates.length - 1]
    readonly property real scale: store.monScale || mon.scale || 1 // what's actually set, auto included
    readonly property var scales: ["auto", "1", "1.25", "1.5", "2"]
    function windows() {
        const s = store;
        hypr(`hl.config({ general = { gaps_in = ${s.gapsIn}, gaps_out = ${s.gapsOut}, border_size = ${s.border} }, `
           + `decoration = { rounding = ${s.rounding}, blur = { enabled = ${blurOn} }, shadow = { enabled = ${shadowOn} } } })`);
    }
    // note: on/off only; slam/snap would mean overriding the curves from animations.lua
    function motion() { hypr(`hl.config({ animations = { enabled = ${moving} } })`); }
    readonly property var switches: [["alt+shift", "grp:alt_shift_toggle"], ["caps", "grp:caps_toggle"], ["ctrl+shift", "grp:ctrl_shift_toggle"]]
    function input() {
        const s = store;
        hypr(`hl.config({ input = { kb_options = "${switches[s.kbSwitch]?.[1] ?? switches[0][1]}", repeat_delay = ${s.repeatDelay}, repeat_rate = ${s.repeatRate}, `
           + `sensitivity = ${s.sens / 100}, accel_profile = "${s.flat ? "flat" : "adaptive"}", touchpad = { natural_scroll = ${s.natural}, `
           + `tap_to_click = ${s.tap}, disable_while_typing = ${s.typingOff}, scroll_factor = ${s.scroll / 100} } } })`);
    }
    // hibernate isn't everywhere (it needs swap under resume, zram won't do) — ask logind. without it, plain suspend and
    // the hibernate entries hide. the answer landed after idle() — rewrite the config (the lock never calls idle(), it doesn't care)
    property bool canHibernate: false
    property bool idleDone: false
    readonly property bool hibernateOn: store.hibernate && canHibernate
    onCanHibernateChanged: if (idleDone) idle()
    Process {
        running: true
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanSuspendThenHibernate"]
        stdout: StdioCollector { onStreamFinished: root.canHibernate = text.includes('"yes"') }
    }
    // hypridle doesn't reread its config on the fly: write mine and restart it. same text and hypridle alive — leave it
    // be, so a shell reload doesn't reset the idle counter. inhibit_sleep = 3 — sleep waits until the lock is up (hypridle
    // only waits like that for hyprlock): otherwise the lock suspends half-raised, and on wake the monitors blink — a
    // monitor vanishing in the lock's first ~0.5 s takes qs down (#5)
    function idle() {
        idleDone = true;
        const s = store, dpms = a => `hyprctl dispatch 'hl.dsp.dpms({action = "${a}"})'`;
        const at = (min, on, back) => min ? `\nlistener {\n    timeout = ${min * 60}\n    on-timeout = ${on}${back ? `\n    on-resume = ${back}` : ""}\n}\n` : "";
        const conf = "# pulse: written by Rules.idle() from rules.json, don't edit by hand\n"
            + "general {\n    lock_cmd = ~/.config/quickshell/rice/rice lock\n    inhibit_sleep = 3\n"
            + `    before_sleep_cmd = loginctl lock-session\n    after_sleep_cmd = ${dpms("on")}\n}\n`
            + at(s.lockAfter, "loginctl lock-session") + at(s.dpmsAfter, dpms("off"), dpms("on"))
            + at(s.sleepAfter, hibernateOn ? "systemctl suspend-then-hibernate" : "systemctl suspend");
        Quickshell.execDetached(["sh", "-c", 'f="$1/hypridle.conf"; printf %s "$2" | cmp -s - "$f" && pgrep -x hypridle >/dev/null && exit; '
                                       + 'printf %s "$2" > "$f"; systemctl --user restart pulse-hypridle.service 2>/dev/null && exit; '
                                       + 'pkill -x hypridle; exec hypridle -c "$f"', "sh", dir, conf]);
    }
    function brightness() { Quickshell.execDetached(["brightnessctl", "-q", "set", store.brightness + "%"]); }
    function night() {
        // hyprsunset is the pulse-hyprsunset unit: it reads the warmth file at start. no systemd — spawn it here
        Quickshell.execDetached(["sh", "-c", store.night
            ? 'mkdir -p "$HOME/.local/state/rice"; printf \'%s\\n\' "$1" > "$HOME/.local/state/rice/warmth"; '
              + 'systemctl --user restart pulse-hyprsunset.service 2>/dev/null && exit; pkill -x hyprsunset; exec hyprsunset -t "$1"'
            : 'systemctl --user stop pulse-hyprsunset.service 2>/dev/null && exit; pkill -x hyprsunset',
            "sh", String(store.warmth)]);
    }

    // palette: Skin repaints itself (bindings on pal); this covers what lives outside the shell
    function paint() {
        const c = pal.c;
        if (store.paintHypr) {
            const h = c.map(x => x.slice(1));
            hypr(`hl.config({ general = { col = { active_border = { colors = { "rgb(${h[5]})", "rgb(${h[4]})", "rgb(${h[5]})" }, angle = 135 }, `
               + `inactive_border = "rgb(${h[2]})" } }, decoration = { shadow = { color = "rgba(${h[5]}20)" } } })`);
        }
        if (store.paintKitty) {
            kitty.setText([
                ["foreground", c[7]], ["background", c[1]], ["cursor", c[7]], ["cursor_text_color", c[1]],
                ["selection_foreground", c[7]], ["selection_background", c[3]], ["url_color", c[4]],
                ["active_border_color", c[5]], ["inactive_border_color", c[2]],
                ["active_tab_foreground", c[7]], ["active_tab_background", c[5]],
                ["inactive_tab_foreground", c[6]], ["inactive_tab_background", c[1]], ["tab_bar_background", c[0]]
            ].map(([k, v]) => `${k} ${v}`).join("\n") + "\n");
            Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
        }
    }

    // power modes like caelestia's: the power-profiles-daemon profile. ultra on top — 60 hz, no animations, blur or
    // shadows, layered over my settings without touching them: step off and they're back. 0 ultra · 1 saver · 2 balanced · 3 performance.
    // windows (blur, shadows) are applied by the caller: pulse — Skin.apply() (windows() would wipe its rounding)
    readonly property var modes: [
        { name: "ultra", short: "ULT", what: `power saver · ${rates[0]} hz · still` },
        { name: "saver", short: "ECO", what: "power saver" },
        { name: "balanced", short: "BAL", what: "balanced" },
        { name: "performance", short: "MAX", what: "performance" }
    ]
    readonly property int mode: store.ultra ? 0 : PowerProfiles.profile + 1
    readonly property int modeCount: PowerProfiles.hasPerformanceProfile ? 4 : 3
    function setMode(i) {
        i = Math.max(0, Math.min(modeCount - 1, i));
        const hz0 = hz, moving0 = moving;
        store.ultra = i === 0;
        PowerProfiles.profile = i === 0 ? PowerProfile.PowerSaver : i - 1;
        // the monitor — only the built-in one, and only when the hz really change: reconfiguring the output blinks the
        // screen and kills hover (the panels fade out)
        if (hz !== hz0 && mon.name) {
            hypr(rule(mon));
            monReread.restart();
        }
        if (moving !== moving0) motion();
    }
    // what's actually in effect: ultra overrides the settings with the screen's lowest hz, else the closest to what was picked
    readonly property int hz: store.ultra ? rates[0] : refreshHz
    readonly property bool moving: store.motion && !store.ultra && !store.game
    readonly property bool blurOn: store.blur && !store.ultra && !store.game
    readonly property bool shadowOn: store.shadow && !store.ultra && !store.game

    // shell startup: everything but brightness (the keys and the osd drive it, stomping it on every launch is off the table)
    function applyAll() {
        monitor(); windows(); motion(); night(); paint(); input(); idle();
    }
}
