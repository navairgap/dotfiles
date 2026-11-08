import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components

// pulse: the screen edges as leds on the back of a phone, instead of osds and popups in the middle of the screen.
// top — a flash per notification (red when critical) and the island holding it, right — volume/brightness rising from
// the bottom, bottom — long-task progress (notifications with the value hint) or the focus timer (Focus). out after 3 s
Scope {
    id: root

    // the flash and island tuck under the bar when it sits on top of the focused screen (that's where they land too)
    readonly property bool underBar: Skin.state.barAt === "top" && Skin.scr(Hyprland.focusedMonitor?.name, "bar")

    // ---- right: volume and brightness ----
    property string kind: "vol"
    property real value: 0
    property bool armed: false // the startup values stay unseen
    Timer { running: true; interval: 1500; onTriggered: root.armed = true }
    function level(k, v) {
        if (!armed || !Skin.state.edges) return;
        kind = k;
        value = v;
        side.shown = true;
        sideT.restart();
    }
    Connections {
        target: Sys.sink?.audio ?? null
        function onVolumeChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
        function onMutedChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
    }
    Connections {
        target: Sys
        function onBriChanged() { root.level("bri", Sys.bri); }
    }
    Timer { id: sideT; interval: 3000; onTriggered: side.shown = false }

    // ---- top: a new notification — the strip flashes and a card joins the island stack ----
    property var note: null // the latest, for the flash
    // the stack: field snapshots (a notification can be dismissed while its card is still leaving — the object is gone),
    // the object itself lives in refs for its action
    ListModel { id: stack }
    property var refs: ({})
    property int seq: 0
    readonly property int most: 4
    // card into the stack: c — { app, summary, body, icon (icon theme), pulse (nerd font), crit }; ref — the notification, for its action
    function push(c, ref) {
        root.note = { urgency: c.crit ? NotificationUrgency.Critical : NotificationUrgency.Normal };
        noteT.restart();
        const key = String(++root.seq);
        if (ref) root.refs[key] = ref;
        stack.insert(0, Object.assign({ key, app: "", summary: "", body: "", icon: "", pulse: "", crit: false, leaving: false }, c));
        // past most — the oldest live one leaves
        let live = 0;
        for (let i = 0; i < stack.count; i++) if (!stack.get(i).leaving && ++live > root.most) stack.setProperty(i, "leaving", true);
    }
    Connections {
        target: Notes
        function onArrived(n) {
            root.push({ app: n.appName || "app", summary: n.summary ?? "", body: n.body ?? "", icon: n.appIcon ?? "",
                        crit: n.urgency === NotificationUrgency.Critical }, n);
        }
    }

    // ---- power: charger in/out, charged full, running down (15% warn, 5% in red). as a card in the island,
    // bypassing notification history. armed — not at startup ----
    readonly property var bat: UPower.displayDevice
    readonly property int pct: Math.round((bat?.percentage ?? 0) * 100)
    property int warned: 100
    function hm(s) { const m = Math.round(s / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    function power(summary, pulse, crit, time) {
        if (root.armed && root.bat?.isLaptopBattery) root.push({ app: "power", summary, body: `${root.pct}%` + (time ? ` · ${time}` : ""), pulse, crit: !!crit });
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.warned = 100;
            if (UPower.onBattery) root.power("On battery", "\u{F0079}", false, root.bat.timeToEmpty ? `${root.hm(root.bat.timeToEmpty)} left` : "");
            else root.power("Charging", "\u{F0084}", false, root.bat.timeToFull ? `full in ${root.hm(root.bat.timeToFull)}` : "");
        }
    }
    Connections {
        target: root.bat
        function onStateChanged() { if (root.bat.state === UPowerDeviceState.FullyCharged && !UPower.onBattery) root.power("Fully charged", "\u{F0079}"); }
        function onPercentageChanged() {
            if (!UPower.onBattery) return;
            if (root.pct <= 5 && root.warned > 5) { root.warned = 5; root.power("Battery critical", "\u{F0083}", true, "plug in now"); }
            else if (root.pct <= 15 && root.warned > 15) { root.warned = 15; root.power("Battery low", "\u{F0083}", false, "plug in soon"); }
        }
    }
    function dismiss(key) { for (let i = 0; i < stack.count; i++) if (stack.get(i).key === key) return stack.setProperty(i, "leaving", true); }
    function forget(key) {
        delete refs[key];
        for (let i = 0; i < stack.count; i++) if (stack.get(i).key === key) return stack.remove(i);
    }
    Timer { id: noteT; interval: 3000; onTriggered: root.note = null }
    readonly property bool crit: note?.urgency === NotificationUrgency.Critical

    Edge {
        id: top
        shown: !!root.note && Skin.state.edges
        anchors.top: true
        margins.top: root.underBar ? Math.ceil(78 * Skin.s) : 0
        implicitWidth: Math.ceil(640 * Skin.s)
        implicitHeight: Math.ceil(30 * Skin.s)
        Seg {
            x: 20
            y: 4
            width: 600
            height: 4
            n: 12
            f: 1
            on: root.crit ? Skin.red : Skin.fg
            layer.enabled: true
            layer.effect: Glow {}
            SequentialAnimation on opacity {
                running: top.shown
                loops: Animation.Infinite
                NumberAnimation { from: 0.15; to: 1; duration: 720; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.15; duration: 1680; easing.type: Easing.InOutSine }
            }
        }
    }

    // island: a stack of cards top-center, newest first. white outline (red when critical), icon in a circle, one red dot.
    // each card plays the dynamic island: drops in as a pill, blooms into a card, text fades in last; on the way out it
    // folds back into a pill and its slot collapses — the lower ones slide up. each lives 4 s on its own, hovering the
    // stack holds them all. the window is a fixed size (room for most cards), only the stack itself catches the mouse
    PanelWindow {
        visible: stack.count > 0
        anchors.top: true
        margins.top: root.underBar ? Math.ceil(78 * Skin.s) : 0
        implicitWidth: Math.ceil(600 * Skin.s)
        implicitHeight: Math.ceil((24 + root.most * 132) * Skin.s)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: col }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "pulse-island"

        Stage {
            Column {
                id: col
                y: 24
                width: 600
                HoverHandler { id: hov }

                Repeater {
                    model: stack

                    Item {
                        id: c
                        required property int index
                        required property string key
                        required property string app
                        required property string summary
                        required property string body
                        required property string icon
                        required property string pulse
                        required property bool crit
                        required property bool leaving

                        // p 0…1 linear, each phase gets its own ease-out-quart (like glide)
                        property real p: 0
                        Component.onCompleted: p = Qt.binding(() => leaving ? 0 : 1)
                        Behavior on p { NumberAnimation { duration: c.leaving ? 450 : 700 } }
                        onPChanged: if (leaving && p <= 0) Qt.callLater(root.forget, key)
                        function ph(a, b) { const x = Math.max(0, Math.min(1, (p - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }
                        readonly property real drop: ph(0, 0.3)   // the pill drops in
                        readonly property real grow: ph(0.25, 0.8) // and blooms into a card
                        readonly property real full: Math.max(86, txt.height + 32)

                        width: 600
                        height: (40 + (full - 40) * grow + 12) * drop // the stack slot grows and collapses along with the card
                        Timer { running: !c.leaving && !hov.hovered; interval: 4000; onTriggered: root.dismiss(c.key) }

                        Rectangle {
                            width: 140 + (600 - 140) * c.grow
                            height: 40 + (c.full - 40) * c.grow
                            x: (600 - width) / 2
                            y: -24 * (1 - c.drop)
                            opacity: c.drop
                            radius: Skin.corner(Math.min(34, height / 2))
                            clip: true
                            color: Skin.s1
                            border { width: 1; color: c.crit ? Skin.red : Skin.fg }

                            // content laid out full-size, centered: text width holds still while the card grows
                            Item {
                                anchors.centerIn: parent
                                width: 600
                                height: c.full
                                opacity: c.ph(0.7, 1)

                                Rectangle {
                                    id: ic
                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 54
                                    height: 54
                                    radius: 27
                                    color: Skin.s2
                                    Icon { anchors.centerIn: parent; visible: !img.visible; text: c.pulse || "\u{F009A}"; font.pixelSize: 24 }
                                    Image {
                                        id: img
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        visible: status === Image.Ready
                                        source: c.icon ? Quickshell.iconPath(c.icon, true) : ""
                                        sourceSize: Qt.size(28, 28)
                                        layer.enabled: true
                                        layer.effect: Dm { step: 2 }
                                    }
                                }
                                Column {
                                    id: txt
                                    anchors { left: ic.right; leftMargin: 16; right: dot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                    Lb { width: parent.width; elide: Text.ElideRight; text: `${c.app} · now` }
                                    Text {
                                        width: parent.width
                                        topPadding: 2
                                        elide: Text.ElideRight
                                        text: c.summary
                                        textFormat: Text.PlainText
                                        font { family: Skin.ui; pixelSize: 17; weight: Font.DemiBold }
                                        color: Skin.fg
                                    }
                                    Text {
                                        width: parent.width
                                        visible: !!c.body
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        text: c.body
                                        font { family: Skin.ui; pixelSize: 14 }
                                        color: Skin.grey
                                    }
                                }
                                // the red dot — newest card only: one red thing on screen
                                Rectangle { id: dot; visible: c.index === 0; anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter } width: 12; height: 12; radius: 6; color: Skin.accent }
                            }

                            // click — the default action; the card leaves, the notification stays in history. it may already
                            // be dismissed — what's left of the object is an empty wrapper without actions
                            TapHandler {
                                onTapped: {
                                    root.refs[c.key]?.actions?.find(a => a.identifier === "default")?.invoke();
                                    root.dismiss(c.key);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- right ----
    Edge {
        id: side
        anchors.right: true
        implicitWidth: Math.ceil(160 * Skin.s)
        implicitHeight: Math.ceil(520 * Skin.s)
        Lit {
            x: 160 - 5 - 5
            y: 10
            width: 5
            height: 500
            n: 20
            vertical: true
            f: root.value
        }
        Tag {
            vertical: true // a vertical strip gets an upright capsule: icon above the number
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            Icon { text: root.kind === "bri" ? "\u{F00E0}" : Sys.muted ? "\u{F075F}" : "\u{F057E}" }
            Num { text: Math.round(root.value * 100); font.pixelSize: 30 }
        }
    }

    // ---- bottom: task progress, else the running focus timer (one bare strip, no capsule: it hangs around for tens of minutes) ----
    readonly property var task: Notes.task
    readonly property real progress: task ? Math.max(0, Math.min(100, task.hints.value ?? 0)) / 100 : Focus.f
    Connections {
        target: Focus
        function onDone() { root.push({ app: "focus", summary: "Focus done", body: `${Focus.minutes} min`, pulse: "\u{F13AB}" }); }
    }
    Edge {
        shown: (!!root.task || Focus.running) && Skin.state.edges
        anchors.bottom: true
        implicitWidth: Math.ceil(1100 * Skin.s)
        implicitHeight: Math.ceil(110 * Skin.s)
        Lit {
            x: 10
            y: 110 - 5 - 5
            width: 1080
            height: 5
            n: 40
            f: root.progress
        }
        Tag {
            visible: !!root.task
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            Icon { text: "\u{F01DA}" }
            Lb { text: root.task?.summary ?? ""; color: Skin.fg }
            Num { text: Math.round(root.progress * 100) + "%"; font.pixelSize: 26 }
        }
    }

    // a strip at the edge: the mouse sees through it, drawn in layout pixels
    component Edge: PanelWindow {
        property bool shown
        default property alias content: st.data
        visible: shown
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "pulse-edge"
        Stage { id: st }
    }
    // the value capsule next to a strip; vertical stacks its contents
    component Tag: Rectangle {
        default property alias content: box.data
        property bool vertical
        width: vertical ? Math.max(52, box.width + 24) : box.width + 32
        height: vertical ? box.height + 36 : 52
        radius: Skin.corner(Math.min(width, height) / 2)
        color: Skin.s1
        border { width: 1; color: Skin.s2 }
        Grid {
            id: box
            anchors.centerIn: parent
            columns: parent.vertical ? 1 : 99
            spacing: parent.vertical ? 10 : 12
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
        }
    }
    // the glow of lit segments — the only "shadow" in the whole shell
    component Glow: MultiEffect {
        shadowEnabled: true
        shadowColor: Skin.glow
        shadowBlur: 0.7
        blurMax: 20
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
