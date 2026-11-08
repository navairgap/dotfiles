pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// screen backlight, like in caelestia — no hardwired device: whatever brightnessctl picks by default (the first backlight).
// the value comes from sysfs: inotify is silent on it, but a write to brightness sends a uevent change — i wait for that
// from udev, no polling. no backlight (a desktop) — empty dev, value 0. ponytail: external monitors over ddc (ddcutil, like
// caelestia) — no
Singleton {
    id: root

    property string dev: ""       // /sys/class/backlight/<name>
    property real value: 0        // 0…1
    property int steps: 20        // divisions on the scale for the keys; pulse sets it from settings (Sys)
    signal moved()                // every uevent, even when the value is the same (key held at max) — for the osd

    function read() {
        cur.reload();
        const v = parseInt(cur.text());
        if (!isNaN(v)) value = v / (parseInt(max.text()) || 1);
    }
    // value goes up right away, no waiting for brightnessctl and the uevent; while my own writes are in flight their
    // uevents aren't read — sync will reconcile. a raw number, not a percent: rounding to % would break the step() grid
    // (81% → up → 99, not 100)
    function set(v) {
        const m = parseInt(max.text()) || 0;
        if (!m) return;
        const raw = Math.round(Math.max(0.01, Math.min(1, v)) * m);
        value = raw / m;
        sync.restart();
        Quickshell.execDetached(["brightnessctl", "-q", "-d", dev.slice(dev.lastIndexOf("/") + 1), "set", String(raw)]);
    }
    // keys: steps divisions by the 4th root (20 — brightnessctl's -e4, 5% apiece), finer near the bottom of the scale. the step
    // counts from the nearest division, not from value: otherwise the float error piles up (up lands on 399998 instead of 400000)
    function step(d) {
        set(Math.pow(Math.max(0, Math.min(steps, Math.round(Math.pow(value, 0.25) * steps) + d)) / steps, 4));
        moved();
    }
    Timer { id: sync; interval: 300; onTriggered: root.read() }
    GlobalShortcut { appid: "shell"; name: "briUp"; description: "brightness +"; onPressed: root.step(1) }
    GlobalShortcut { appid: "shell"; name: "briDown"; description: "brightness −"; onPressed: root.step(-1) }

    FileView { id: cur; path: root.dev ? root.dev + "/brightness" : ""; blockAllReads: true; printErrors: false }
    FileView { id: max; path: root.dev ? root.dev + "/max_brightness" : ""; blockLoading: true; printErrors: false }

    // brightnessctl -m: "name,class,current,percent,max"
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim().split(",")[0];
                if (!name) return;
                root.dev = "/sys/class/backlight/" + name;
                root.read();
            }
        }
    }
    Process {
        running: !!root.dev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser { onRead: l => { if (l.includes(" change ")) { if (!sync.running) root.read(); root.moved(); } } }
    }
}
