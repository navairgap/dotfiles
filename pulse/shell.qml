//@ pragma IconTheme Rice
// my own icon theme, not qtengine's: when that engine fails to load, qt only searches hicolor
// and apps like kcalc end up with empty circles (#11)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "bar"
import "buds"
import "cal"
import "charms"
import "clip"
import "deck"
import "edge"
import "home"
import "launcher"
import "overview"
import "power"
import "prefs"
import "quick"
import "settings"
import "shot"
import "snap"
import "switch"
import "vpn"
import "wall"

// pulse: a rice in the spirit of nothing os. home over the wallpaper, the bar, launcher, quick settings,
// edge light strips instead of osds, the notification island, power menu, settings, deck (the dashboard at the
// bottom), clipboard, charms (emoji and symbols), screenshots, vpn, wallpaper. locking is a separate process (lock.qml).
// `rice switch` / the Rice app flips between shells — hypr binds (shell:*) are shared, each shell claims its own
ShellRoot {
    id: shell

    Launcher { id: launcher }
    Quick { id: quick; onPowerRequested: power.open(); onSettingsRequested: prefs.open() }
    Power { id: power }
    Prefs { id: prefs; onWallRequested: walls.open() }
    Edge {}
    Buds {}
    Cal { id: cal }
    Clip { id: clip }
    Charms { id: charms }
    Deck { id: deck }
    Shot { id: shot }
    Switcher { id: switcher }
    Overview { id: overview }
    Zones { id: zones }
    Vpn { id: vpn }
    Walls { id: walls }

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            Back { screen: s.modelData }
            // bar and home can be pulled off a screen (settings → display), the wallpaper stays. bound here, not inside
            // the window: visible from the window's own screen loops (window recreated, screen changes)
            Home {
                screen: s.modelData
                visible: Skin.scr(s.modelData.name, "home")
                menuItems: [
                    { label: "wallpapers", run: () => walls.toggle() },
                    { label: "deck", run: () => deck.toggle() },
                    { label: "quick settings", run: () => quick.toggle() },
                    { label: "launcher", run: () => launcher.open() },
                    { label: "display", run: () => prefs.open() },
                    "-",
                    { label: "overview", run: () => overview.toggle() },
                    { label: "lock", run: () => Quickshell.execDetached(["sh", "-c", "~/.config/quickshell/rice/rice lock"]) },
                    { label: "power menu", run: () => power.open() }
                ]
            }
            Hot { screen: s.modelData; onTriggered: quick.peek() }
            Bar {
                screen: s.modelData
                visible: Skin.scr(s.modelData.name, "bar")
                onMarkClicked: launcher.toggle()
                onTrayClicked: quick.toggle()
                onPowerClicked: power.visible ? power.close() : power.open()
                onClockClicked: cal.toggle()
            }
        }
    }

    // hypr gets set up in two layers: Rules (settings/Rules.qml, the same ~/.config/pulse/rules.json) places the monitor,
    // input, motion, night light and hypridle; Skin.apply layers my border colors, rounding and kitty on top —
    // that one runs again on a theme change
    Component.onCompleted: {
        hypr();
        if (Skin.state.paint) Skin.apps(); // rice start leaves term/ links behind — bring the colors back
        Rules.night();
        Rules.idle();
    }
    // whatever lives in the hypr config. hypr rereads it itself: save any hypr file (the links are live — git pull or a
    // branch switch counts), hyprctl reload, and variables.lua defaults return: monitor, input, animations, borders.
    // so mine go on again. hyprctl eval never sends configreloaded — no loop. night light and hypridle are my own
    // processes, reload leaves them alone
    function hypr() {
        Rules.monitor();
        Rules.input();
        Rules.motion();
        Skin.apply();
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "configreloaded") shell.hypr(); }
    }
    // a screen was plugged in — its scale and hz live in prefs → display (Rules.store.outs)
    Connections {
        target: Quickshell
        function onScreensChanged() { Rules.monitor(true); }
    }
    Connections {
        target: Skin
        function onGreysChanged() { paint.restart(); }
    }
    // theme or color changed (style, new wallpaper) — windows, kitty, gtk and qt. after 300 ms: the new wallpaper's
    // tones don't land at once, and gtk shouldn't be poked twice
    Timer { id: paint; interval: 300; onTriggered: { Skin.apply(); Skin.apps(); } }
    // wallpaper tones (Skin.pick) live here, not in Skin: the lock loads Skin too and is happy with the ready ones from
    // pulse.json. empty means the wallpaper copy didn't load (grey would give 16 colors): keep the old tones.
    // a new wallpaper starts from the first tone
    ColorQuantizer {
        source: Skin.url(Skin.wallSrc(Skin.wall))
        depth: 4
        rescaleSize: 64
        onColorsChanged: {
            if (!colors.length) return;
            const t = Skin.pick(colors);
            if (t.join() === Skin.state.tones.join()) return;
            Skin.state.tones = t;
            Skin.state.paintAt = 0;
        }
    }
    Connections {
        target: Skin.state
        function onRoundingChanged() { Skin.apply(); }
    }
    // ultra flips blur and shadows over the settings — repaint the windows (Rules.setMode handles hz and motion itself).
    // game mode is the same, plus animations
    Connections {
        target: Rules.store
        function onUltraChanged() { Skin.apply(); }
        function onGameChanged() { Rules.motion(); Skin.apply(); }
    }

    // a super tap opens the launcher on release; any super+<key> along the way sends interrupt, and the launcher stays shut
    property bool interrupted: false
    Shortcut {
        name: "launcher"
        description: "launcher (tap super)"
        onReleased: {
            if (!shell.interrupted) launcher.toggle();
            shell.interrupted = false;
        }
    }
    Shortcut { name: "launcherArm"; description: "super press — clear interrupt"; onPressed: shell.interrupted = false }
    Shortcut { name: "launcherInterrupt"; description: "super+<key> — keep the launcher shut"; onPressed: shell.interrupted = true }
    // super+space — deck, the bottom dashboard: the launcher already owns a super tap
    Shortcut { name: "altar"; description: "deck: the bottom dashboard"; onPressed: deck.toggle() }
    Shortcut { name: "quick"; description: "quick settings"; onPressed: quick.toggle() }
    Shortcut { name: "ward"; description: "quick settings"; onPressed: quick.toggle() } // same toggles under super+n, so switching shells doesn't break the habit
    Shortcut { name: "settings"; description: "settings"; onPressed: prefs.toggle() }
    Shortcut { name: "power"; description: "power menu"; onPressed: power.visible ? power.close() : power.open() }
    Shortcut { name: "shot"; description: "screenshot"; onPressed: shot.open() }
    Shortcut { name: "pact"; description: "vpn: clash verge"; onPressed: vpn.toggle() }
    Shortcut { name: "clip"; description: "clipboard"; onPressed: clip.toggle() }
    Shortcut { name: "charms"; description: "emoji, kaomoji, symbols"; onPressed: charms.toggle() }
    Shortcut { name: "wall"; description: "wallpaper"; onPressed: walls.toggle() }
    Shortcut { name: "game"; description: "game mode"; onPressed: Rules.store.game = !Rules.store.game }
    // alt-tab: hold the mod, tap, release. the mod release comes through onReleased; cancel is alt+escape
    Shortcut {
        name: "switcherNext"
        description: "next window (alt-tab, super+tab)"
        onPressed: switcher.step(1)
        onReleased: switcher.arm()
    }
    Shortcut {
        name: "switcherPrev"
        description: "previous window (shift+alt-tab)"
        onPressed: switcher.step(-1)
        onReleased: switcher.arm()
    }
    Shortcut { name: "switcherCancel"; description: "put the switcher down"; onPressed: switcher.cancel() }
    Shortcut { name: "overview"; description: "overview: every workspace on one scrim"; onPressed: overview.toggle() }
    // snap zones: hypr moves the window, these just flash the region it landed on (pulse/snap)
    Shortcut { name: "zoneLeft"; description: "snap left half"; onPressed: zones.flash("left") }
    Shortcut { name: "zoneRight"; description: "snap right half"; onPressed: zones.flash("right") }
    Shortcut { name: "zoneMax"; description: "snap full screen"; onPressed: zones.flash("max") }
    Shortcut { name: "zoneCenter"; description: "snap centered"; onPressed: zones.flash("center") }
    Shortcut { name: "zoneTl"; description: "snap top left quarter"; onPressed: zones.flash("tl") }
    Shortcut { name: "zoneTr"; description: "snap top right quarter"; onPressed: zones.flash("tr") }
    Shortcut { name: "zoneBl"; description: "snap bottom left quarter"; onPressed: zones.flash("bl") }
    Shortcut { name: "zoneBr"; description: "snap bottom right quarter"; onPressed: zones.flash("br") }

    component Shortcut: GlobalShortcut { appid: "shell" }
}
