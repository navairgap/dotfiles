import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// the home screen: bottom layer, transparent — doto clock, greeting, bento widgets. the grid, orb and wallpaper
// live under it, in Back. anything that opens just lands on top of the window on its own. i only poll the system
// and run animations while the workspace is empty
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "pulse-home"

    // home is up when this screen's own workspace is empty — not wherever focus sits: work on the second monitor
    // and the first one's home stays alive
    function idle(s) { return (Hyprland.monitorFor(s)?.activeWorkspace?.toplevels.values.length ?? 0) === 0; }
    readonly property bool home: visible && idle(screen)
    // these flags are shared across all homes (every screen that has one up): otherwise the bindings of
    // neighbouring homes would stomp on each other. and not inside a widget — a destroyed Binding doesn't put the
    // value back, so yank the widget and cava would run forever.
    // note: cava turns on when it's in the list, even if it doesn't fit into the 3 × 3
    readonly property var homes: Quickshell.screens.filter(s => Skin.scr(s.name, "home") && idle(s))
    Binding { target: SysStats; property: "detailed"; value: root.homes.length > 0 || Sys.deckOpen }
    Binding { target: Cava; property: "active"; value: root.homes.some(s => Skin.scr(s.name, "widgets").includes("cava")) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")

    // blinking colon — two flips a second, not an animation on every vsync
    property bool dim: false
    Timer { running: root.home && Skin.state.blink; interval: 500; repeat: true; onTriggered: root.dim = !root.dim }

    readonly property var player: Media.player
    readonly property var buds: Bluetooth.devices.values.find(d => d.connected && d.batteryAvailable) ?? null
    property var hist: [] // cpu over the last minute: the 34 matrix columns
    Connections {
        target: SysStats
        function onCpuChanged() { root.hist = root.hist.concat([SysStats.cpu]).slice(-34); }
    }

    function week(d) { // iso week number
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    readonly property string hello: { const h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"; }

    Stage {
        id: stage
        // laid out for a bar on the left; bar on top or taken off — slide half its width left to stay centered
        x: Skin.state.barAt === "top" || !Skin.scr(root.screen?.name, "bar") ? -39 * Skin.s : 0

        Row {
            x: 182
            y: 150
            Num { text: Skin.hh(clock.date); font.pixelSize: 300 }
            Num { text: ":"; font.pixelSize: 300; opacity: Skin.state.blink && root.dim ? 0.2 : 1 }
            Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 300 }
        }
        Lb {
            x: 190
            y: 448
            text: `${root.en.toString(clock.date, "dddd · d MMMM")} · week ${root.week(clock.date)}`
            px: 14
        }
        Text {
            x: 188
            y: 560
            textFormat: Text.StyledText
            text: `${root.hello},<br><font color="${Skin.grey}">${(Skin.state.name || Quickshell.env("USER")).replace(/&/g, "&amp;").replace(/</g, "&lt;")}.</font>`
            font { family: Skin.ui; pixelSize: 54; weight: Font.Light; letterSpacing: -1 }
            lineHeight: 1.1
            color: Skin.fg
        }
        Row {
            x: 190
            y: 700
            spacing: 28
            Meta { icon: "\u{F009A}"; text: `${Notes.list.length} notifications` }
            Meta { visible: Weather.ok; icon: Weather.dots(Weather.now?.code ?? 0, Weather.now?.day); text: `${Math.round(Weather.now?.temp ?? 0)}° ${Weather.name(Weather.now?.code)}` }
            Meta { visible: !!root.buds; icon: "\u{F02CB}"; text: `${root.buds?.name ?? ""} · ${Math.round((root.buds?.battery ?? 0) * 100)}%` }
        }

        // the bento: cells 220, gap 20, a 3×3 grid, right edge 80 from the screen edge (1140 at 1920, further out
        // on wider screens). which widgets and in what order — Skin.state.widgets (settings; a screen can have its
        // own), widths — Skin.kinds. filled left to right: doesn't fit in the row — next one; doesn't fit in three
        // rows — doesn't show. a square with a 40 corner or a circle, no other shapes
        Repeater {
            id: bento
            model: {
                const out = [];
                let r = 0, c = 0;
                for (const id of Skin.scr(root.screen?.name, "widgets") ?? []) {
                    const w = Skin.kinds[id];
                    if (!w) continue;
                    if (c + w > 3) { r++; c = 0; }
                    if (r > 2) break;
                    out.push({ id, x: c * 240, y: 150 + r * 240 });
                    c += w;
                }
                return out;
            }
            Loader {
                required property var modelData
                x: stage.width - 780 + modelData.x
                y: modelData.y
                sourceComponent: ({ weather: weatherW, calendar: calendarW, cpu: cpuW, ram: ramW, gpu: gpuW, disk: diskW,
                                    battery: batteryW, buds: budsW, player: playerW, system: systemW, cat: catW, cava: cavaW })[modelData.id] ?? null
            }
        }

        // weather
        Component {
            id: weatherW
            W {
                round: true
                Column {
                    anchors.centerIn: parent
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.dots(Weather.now?.code ?? 3, Weather.now?.day)
                        font.pixelSize: 78
                        layer.enabled: true
                        layer.effect: Dm { step: 4 }
                    }
                    Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 6; text: Weather.ok ? Math.round(Weather.now.temp) + "°" : "--"; font.pixelSize: 66 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 8
                        width: Math.min(implicitWidth, 160) // chord of the circle at this height
                        elide: Text.ElideRight
                        text: Weather.ok ? `${Weather.name(Weather.now.code)} · ${Math.round(Weather.days[0]?.min)}°/${Math.round(Weather.days[0]?.max)}°` : "no sky"
                    }
                }
            }
        }

        // calendar
        Component {
            id: calendarW
            W {
                Column {
                    x: 24
                    y: 24
                    width: parent.width - 48
                    Lb { text: root.en.monthName(clock.date.getMonth()) }
                    Num { topPadding: lead + 8; text: clock.date.getDate(); font.pixelSize: 118 }
                    Row {
                        width: parent.width
                        topPadding: 14
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                required property string modelData
                                required property int index
                                readonly property bool today: (clock.date.getDay() + 6) % 7 === index
                                width: parent.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font { family: Skin.mono; pixelSize: 11 }
                                color: today ? Skin.fg : Skin.grey
                                Rectangle { visible: parent.today; anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } width: 10; height: 2; color: Skin.fg }
                            }
                        }
                    }
                }
            }
        }

        // rings: cpu, memory, gpu, disk, battery
        Component { id: cpuW; RingW { f: SysStats.cpu; value: Math.round(SysStats.cpu * 100); label: "cpu %" } }
        Component { id: ramW; RingW { f: SysStats.mem; value: Math.round(SysStats.mem * 100); label: "ram %" } }
        Component { id: gpuW; RingW { f: SysStats.gpu; value: Math.round(SysStats.gpu * 100); label: `gpu · ${Math.round(SysStats.gpuTemp)}°` } }
        Component { id: diskW; RingW { f: SysStats.disks[0]?.used ?? 0; value: Math.round((SysStats.disks[0]?.used ?? 0) * 100); label: "disk %" } }
        Component {
            id: batteryW
            RingW {
                readonly property var bat: UPower.displayDevice
                f: bat.percentage
                value: Math.round(bat.percentage * 100)
                label: bat.state === UPowerDeviceState.Charging ? "charging" : "battery"
                on: bat.state !== UPowerDeviceState.Charging && bat.percentage < 0.15 ? Skin.red : Skin.fg
            }
        }

        // player: the cover spins as dots while something plays
        Component {
            id: playerW
            W {
                span: 2
                Item {
                    id: art
                    x: 28
                    anchors.verticalCenter: parent.verticalCenter
                    width: 164
                    height: 164
                    property real turn: 0
                    Timer { running: root.home && Media.playing; interval: 33; repeat: true; onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360 }
                    Art { anchors.fill: parent; rotation: art.turn; url: root.player?.trackArtUrl ?? ""; step: 6 }
                }
                Column {
                    anchors { left: art.right; leftMargin: 26; right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                    Lb { text: `now playing · ${root.player?.identity ?? "silence"}`; width: parent.width; elide: Text.ElideRight }
                    Text {
                        width: parent.width
                        topPadding: 10
                        elide: Text.ElideRight
                        text: root.player?.trackTitle || "Nothing on"
                        textFormat: Text.PlainText
                        font { family: Skin.ui; pixelSize: 26; weight: Font.DemiBold }
                        color: Skin.fg
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.player?.trackArtist ?? ""
                        textFormat: Text.PlainText
                        font { family: Skin.ui; pixelSize: 15 }
                        color: Skin.grey
                    }
                    Item { width: 1; height: 18 }
                    Seg { width: parent.width; height: 6; n: 24; f: root.player?.lengthSupported && root.player.length > 0 ? Media.position / root.player.length : 0 } // firefox never sends the length
                    Item { width: 1; height: 16 }
                    Controls { size: 22; play: 52 }
                }
            }
        }

        // buds as a ring; when there are none — volume
        Component {
            id: budsW
            W {
                round: true
                Notch { onNotch: d => Sys.setVol(Sys.vol + d * 0.05) } // wheel — volume, even with buds on: nobody turns their charge with a wheel
                Ring { anchors { fill: parent; margins: 12 } f: root.buds ? root.buds.battery : Sys.vol }
                Column {
                    anchors.centerIn: parent
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: root.buds ? "\u{F02CB}" : "\u{F057E}"; font.pixelSize: 30 }
                    Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 8; text: Math.round((root.buds ? root.buds.battery : Sys.vol) * 100); font.pixelSize: 54 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 6
                        width: 130
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.buds?.name ?? "volume"
                    }
                }
            }
        }

        // the cat: the gif as a matrix in theme tones through the wallpaper shader (Wall at look 0); which gif —
        // services/Gifs, the tile itself — Gif. it only dances while home is up
        Component {
            id: catW
            W {
                id: cw
                Gif { anchors.fill: parent; playing: root.home; bg: cw.color }
            }
        }

        // cava as a matrix in a circle, like the pulse matrix on the back of a nothing phone (3): bass in the
        // middle, treble toward the edges, columns grow up and down from the center. silence — dots out. cava only
        // runs while home is up
        Component {
            id: cavaW
            W {
                round: true
                Grid {
                    anchors.centerIn: parent
                    columns: 15
                    spacing: 4
                    Repeater {
                        model: 15 * 15
                        Rectangle {
                            required property int index
                            readonly property int cx: index % 15 - 7
                            readonly property int cy: Math.floor(index / 15) - 7
                            readonly property int half: Math.floor(Math.sqrt(7.5 * 7.5 - cx * cx)) // half a column's height inside the circle
                            readonly property real v: Cava.bars[Math.abs(cx)] ?? 0
                            width: 8
                            height: 8
                            radius: 4
                            // outside the circle — transparent, not visible:false: Grid would shove the rest around
                            color: Math.abs(cy) > half ? "transparent" : Math.abs(cy) < v * (half + 1) ? Skin.fg : Skin.s3
                        }
                    }
                }
            }
        }

        // system: numbers and a cpu graph as a matrix
        Component {
            id: systemW
            W {
                span: 3
                Grid {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 22
                    Stat { label: "cpu"; value: Math.round(SysStats.cpu * 100) + "%" }
                    Stat { label: "mem"; value: SysStats.memUsed.toFixed(1) + "G" }
                    Stat { label: "gpu"; value: Math.round(SysStats.gpuTemp) + "°" }
                    Stat { label: "disk"; value: Math.round((SysStats.disks[0]?.used ?? 0) * 100) + "%" }
                }
                Column {
                    x: 344
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 34
                    spacing: 12
                    Lb { text: "cpu · 60 s" }
                    // top dot of a column white, the ones under it grey
                    Grid {
                        id: spark
                        width: parent.width
                        columns: 34
                        spacing: 4
                        readonly property real d: (width - 33 * spacing) / 34
                        Repeater {
                            model: 34 * 8
                            Rectangle {
                                required property int index
                                readonly property int x_: index % 34
                                readonly property int up: 8 - Math.floor(index / 34) // 8 at the top … 1 at the bottom
                                readonly property int h: Math.round(1 + 6 * (root.hist[x_ - 34 + root.hist.length] ?? 0))
                                width: spark.d
                                height: spark.d
                                radius: spark.d / 2
                                color: up === h ? Skin.fg : up < h ? Skin.grey : Skin.s2
                            }
                        }
                    }
                }
            }
        }
    }

    component W: Rectangle {
        property int span: 1
        property bool round
        width: span * 220 + (span - 1) * 20
        height: 220
        radius: round ? 110 : Skin.corner(40)
        color: Skin.s1
        border { width: 1; color: Skin.s2 }
    }
    // a round widget: dot ring lit by the share f, number and label in the middle
    component RingW: Rectangle {
        id: rw
        property real f
        property string value
        property string label
        property color on: Skin.fg
        width: 220
        height: 220
        radius: 110
        color: Skin.s1
        border { width: 1; color: Skin.s2 }
        Ring { anchors { fill: parent; margins: 12 } f: rw.f; on: rw.on }
        Column {
            anchors.centerIn: parent
            Num { anchors.horizontalCenter: parent.horizontalCenter; text: rw.value; font.pixelSize: 72 }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 8; text: rw.label }
        }
    }
    component Meta: Row {
        property string icon
        property string text
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; text: parent.icon; font.pixelSize: 16 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: parent.text }
    }
    component Stat: Column {
        property string label
        property string value
        width: 130
        Lb { text: parent.label }
        Num { topPadding: lead + 6; text: parent.value }
    }
}
