pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.services
import qs.settings

// what the bar, quick settings, pulse and the lock reach for: audio, brightness, layout, recording, night light, airplane mode, caffeine, vpn
Singleton {
    id: root

    // deck (the bottom panel) is open — SysStats wants the detailed poll, like on an empty workspace (Home)
    property bool deckOpen: false
    // the wallpaper picker is open — home swaps the wallpaper instantly, no wave: the picker already showed one
    property bool wallOpen: false

    // ---- audio ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var mic: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.mic] }
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property bool micOn: !(mic?.audio?.muted ?? true)
    function setVol(v) {
        if (!sink?.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    // someone is listening to the mic — the bar mark's center goes red
    PwNodeLinkTracker { id: micUse; node: root.mic }
    readonly property bool live: rec || micUse.linkGroups.length > 0

    // ---- brightness: the shared Backlight (brightnessctl finds the device) ----
    readonly property real bri: Backlight.value
    readonly property bool hasBri: !!Backlight.dev // no backlight (a desktop with a monitor) — no brightness controls
    function setBri(v) { Backlight.set(v); }
    Binding { target: Backlight; property: "steps"; value: Skin.state.briSteps }

    // ---- layout: seed from the main keyboard via hyprctl, then follow the activelayout event ----
    property string kbd: ""
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { onStreamFinished: root.kbd = JSON.parse(this.text).keyboards.find(k => k.main)?.active_keymap ?? "" }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") root.kbd = e.data.slice(e.data.lastIndexOf(",") + 1); }
    }
    readonly property string layout: kbd.slice(0, 2).toLowerCase() // "English (US)" → en

    // ---- recording and airplane mode: hypr binds toggle them too, hence the poll. night light lives in rules.json (Rules).
    // note: pgrep every 3 s; if it ever shows up, watch the processes through systemd-run --scope ----
    property bool rec: false
    readonly property bool night: Rules.store.night
    property bool air: false
    Process {
        id: poll
        command: ["sh", "-c", "pgrep -f '^gpu-screen-recorder' >/dev/null && echo rec; "
                            + "rfkill -rno SOFT | grep -qv '^blocked' || echo air"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.rec = text.includes("rec");
                root.air = text.includes("air");
            }
        }
    }
    Timer { running: true; repeat: true; interval: 3000; triggeredOnStart: true; onTriggered: poll.running = true }

    function sh(c) { Quickshell.execDetached(["sh", "-c", c]); }
    // recording settings from Skin.state (quick/Rec) → gpu-screen-recorder flags; the screenshotter reads the same ones
    readonly property var recFps: [30, 60, 120]
    function recArgs() {
        const st = Skin.state;
        const a = ["", "default_output", "default_input", "default_output|default_input"][st.recAudio];
        return `-f ${st.recFps} -q ${["medium", "high", "very_high", "ultra"][st.recQuality]} -cursor ${st.recCursor ? "yes" : "no"}` + (a ? ` -a "${a}"` : "");
    }
    // second call stops it. region via slurp; cancel the selection and gsr never starts, the poll fixes rec
    function toggleRec() {
        const w = Skin.state.recArea ? `-w region -region "$(slurp -f %wx%h+%x+%y)"` : `-w ${Hyprland.focusedMonitor?.name ?? "screen"}`;
        sh(`pkill -INT -f '^gpu-screen-recorder' || exec gpu-screen-recorder ${w} ${recArgs()} -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"`);
        rec = !rec;
    }
    function toggleNight() { Rules.store.night = !night; Rules.night(); }
    function toggleAir() { Quickshell.execDetached(["rfkill", air ? "unblock" : "block", "all"]); air = !air; }
    function toggleMic() { if (mic?.audio) mic.audio.muted = !mic.audio.muted; }

    // ---- nothing / cmf earbuds: anc and battery through ./ear (their rfcomm protocol). asked when quick settings open.
    // note: recognized by name, like gadgetbridge; a non-nothing pair won't answer and ear stays null ----
    readonly property var buds: Bluetooth.devices.values.find(d => d.connected && /^(nothing|cmf|ear)\b/i.test(d.name)) ?? null
    property var ear: null // {mode, l, r, case?}
    onBudsChanged: ear = null
    // right after connecting the channel isn't ready yet — ask every 2 s until it answers. note: an imposter with a
    // similar name keeps getting polled for as long as it stays connected
    Timer { interval: 2000; repeat: true; running: !!root.buds && !root.ear; onTriggered: root.earRun([]) }
    readonly property var ancModes: [[5, "off"], [7, "transp"], [3, "low"], [2, "mid"], [1, "high"], [4, "auto"]]
    property var earNext: null
    function earRun(a) {
        if (!buds) return;
        const c = [Quickshell.shellPath("ear"), buds.address, ...a];
        if (earP.running) earNext = c;
        else { earP.command = c; earP.running = true; }
    }
    function setAnc(m) { ear = Object.assign({}, ear, { mode: m }); earRun(["mode", m]); }
    Process {
        id: earP
        stdout: StdioCollector { onStreamFinished: { try { root.ear = JSON.parse(text); } catch (e) { root.ear = null; } } }
        onExited: if (root.earNext) { command = root.earNext; root.earNext = null; running = true; }
    }

    // ---- bluetooth doesn't reconnect devices on its own when the adapter is powered back (pill, airplane mode, rfkill).
    // bluez drops the connections before it powers the adapter off (Connected:false 40–90 ms ahead of Powered:false), so
    // a snapshot taken at power-off is empty. hence the connected list is written on a delay: powering off cancels it and
    // btResume keeps what was there before. unpaired by hand or earbuds docked in their case — half a second later the
    // list accepts it ----
    readonly property var btOn: Bluetooth.devices.values.filter(d => d.connected).map(d => d.address)
    property var btResume: []
    onBtOnChanged: btKeep.restart()
    Timer { id: btKeep; interval: 500; running: true; onTriggered: if (Bluetooth.defaultAdapter?.enabled && !btResumeT.running) root.btResume = root.btOn }
    Connections {
        target: Bluetooth.defaultAdapter
        function onEnabledChanged() { if (Bluetooth.defaultAdapter.enabled) btResumeT.restart(); else { btKeep.stop(); btResumeT.stop(); } }
    }
    // the adapter needs a moment after power-on
    Timer { id: btResumeT; interval: 1500; onTriggered: { for (const d of Bluetooth.devices.values) if (root.btResume.includes(d.address) && !d.connected) d.connect(); } }

    // ---- caffeine: stay awake. the inhibitor needs a live window — an invisible 0×0 one ----
    property bool caffeine: false
    IdleInhibitor {
        enabled: root.caffeine
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "pulse-caffeine"
            mask: Region {}
        }
    }

    // ---- vpn: clash verge driven through its tray entries.
    // note: the labels are english (language: en in verge); another language — change the strings ----
    readonly property var verge: SystemTray.items.values.find(i => i.title === "clash-verge" || i.id.includes("clash-verge")) ?? null
    QsMenuOpener { id: vmenu; menu: root.verge?.menu ?? null }
    readonly property var vpnItems: ["System Proxy", "TUN Mode"]
    function vpnItem(l) { return vmenu.children.values.find(e => e.text.startsWith(l)) ?? null; }
    readonly property bool vpn: vpnItems.some(l => vpnItem(l)?.checkState === Qt.Checked)
    property var queue: []
    function toggleVpn() {
        if (!verge) return Quickshell.execDetached(["clash-verge"]); // asleep — wake it
        queue = vpn ? vpnItems.filter(l => vpnItem(l)?.checkState === Qt.Checked) : vpnItems;
        presser.start();
    }
    // verge rebuilds its menu after every press — one at a time
    Timer {
        id: presser
        interval: 350
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const [l, ...rest] = root.queue;
            root.queue = rest;
            if (l) root.vpnItem(l)?.triggered();
            if (!rest.length) stop();
        }
    }
}
