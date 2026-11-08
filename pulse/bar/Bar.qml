import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.settings

// bar: a pill at the left edge or across the top — Skin.state.barAt. first the mark (a ring of 16 dots) opens the
// launcher, its center reddens while recording or the mic is live. workspaces as dots, the window title, a doto clock
// in the middle, the tray last — a click opens quick settings. on the side everything stacks, on top it's a row.
// what's in the tray and in which order, whether the title shows — Skin.state (settings, BAR section)
PanelWindow {
    id: root

    signal markClicked
    signal trayClicked
    signal powerClicked
    signal clockClicked

    readonly property bool vert: Skin.state.barAt !== "top" // anything but top (and unknown) sits on the left
    anchors { left: true; right: !vert; top: true; bottom: vert }
    implicitWidth: Math.ceil(78 * Skin.s)  // on the side
    implicitHeight: Math.ceil(78 * Skin.s) // on top
    color: "transparent"
    WlrLayershell.namespace: "pulse-bar"

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    // six dots at least; more when one is occupied or a far one is open
    readonly property int count: Math.min(10, Math.max(6, active, ...Hyprland.workspaces.values.filter(w => w.toplevels.values.length).map(w => w.id)))
    readonly property var top: ToplevelManager.activeToplevel
    readonly property var bat: UPower.displayDevice
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

    // hyprland 0.56 with lua: dispatch takes lua expressions
    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Stage {
        Rectangle {
            id: pill
            x: 14 // off the screen edges
            y: 14
            width: root.vert ? 64 : parent.width - 28
            height: root.vert ? parent.height - 28 : 64
            radius: Skin.corner(32)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }

            Notch { onNotch: d => root.go(d > 0 ? "-1" : "+1") }

            // the mark: a ring of dots, center red while something writes
            Item {
                id: mark
                x: root.vert ? (parent.width - width) / 2 : 18
                y: root.vert ? 18 : (parent.height - height) / 2
                width: 34
                height: 34
                Ring { anchors.fill: parent; n: 16; dot: 3 }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 9
                    radius: 4.5
                    color: !Sys.live ? Skin.fg : Qt.colorEqual(Skin.accent, Skin.fg) ? Skin.red : Skin.accent // monochrome: accent = fg
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.markClicked() }
            }

            // workspaces: the current one stretches into a white pill, occupied ones grey, empty a line
            Pile {
                id: ws
                x: root.vert ? (parent.width - width) / 2 : mark.x + mark.width + 24
                y: root.vert ? mark.y + mark.height + 24 : (parent.height - height) / 2
                spacing: 8

                Repeater {
                    model: root.count

                    Rectangle {
                        required property int index
                        readonly property int n: index + 1
                        readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                        readonly property bool on: root.active === n
                        property real len: on ? 28 : 8
                        width: root.vert ? 8 : len
                        height: root.vert ? len : 8
                        radius: 4
                        color: on ? Skin.fg : occ ? Skin.grey : Skin.s3
                        Behavior on len { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                        Behavior on color { ColorAnimation { duration: Skin.t } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.go(parent.n) }
                    }
                }
            }

            // the window title: from the workspaces to the clock, turned sideways on the side
            Item {
                id: title
                x: root.vert ? (parent.width - width) / 2 : ws.x + ws.width + 24
                y: root.vert ? ws.y + ws.height + 24 : (parent.height - height) / 2
                width: root.vert ? 20 : Math.max(0, clk.x - 24 - x)
                height: root.vert ? Math.max(0, clk.y - 24 - y) : 20
                clip: true
                visible: Skin.state.barTitle
                Lb {
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    width: root.vert ? parent.height : parent.width
                    rotation: root.vert ? 90 : 0
                    elide: Text.ElideRight
                    visible: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
                    text: root.top ? `${root.top.appId.split(".").pop()} · ${root.top.title}` : ""
                    px: 11
                }
            }

            // the clock: on the side a column, 14 over 32 plus the day; on top a row. click — calendar and focus timer (cal/Cal)
            Pile {
                id: clk
                anchors.centerIn: parent
                TapHandler { onTapped: root.clockClicked() }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                Num { text: Skin.hh(clock.date); font.pixelSize: 30 }
                Num { visible: !root.vert; text: ":"; font.pixelSize: 30 }
                Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 30 }
                Lb {
                    topPadding: root.vert ? 8 : 0
                    leftPadding: root.vert ? 0 : 12
                    text: Qt.locale("en_US").toString(clock.date, "ddd d")
                    px: 10
                }
            }

            // the tray — Skin.state.bar in order (settings, BAR section). layout, network, bluetooth, sound (scroll for
            // volume), notifications, battery, the running cat: a click opens quick settings. power mode and power keep their own clicks
            Pile {
                x: root.vert ? (parent.width - width) / 2 : parent.width - width - 22
                y: root.vert ? parent.height - height - 22 : (parent.height - height) / 2
                spacing: 20

                Repeater {
                    model: Skin.state.bar
                    Loader {
                        id: part
                        required property string modelData
                        readonly property bool quick: modelData !== "mode" && modelData !== "power"
                        sourceComponent: root.parts[modelData] ?? null
                        visible: !!sourceComponent && (modelData !== "battery" || root.bat.isLaptopBattery)
                        TapHandler { enabled: part.quick; onTapped: root.trayClicked() }
                        HoverHandler { enabled: part.quick; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
    readonly property var parts: ({ layout: layoutC, wifi: wifiC, bluetooth: btC, sound: soundC, notes: notesC, battery: batC, mode: modeC, power: powerC, cat: catC })
    Component { id: layoutC; Lb { text: Sys.layout; px: 10 } }
    // the runcat cat: the busier the cpu, the faster it runs (250 ms a frame idle, 50 at full). cpu is polled while the cat
    // sits in the tray; the binding stays outside the delegate — a destroyed one wouldn't hand the value back. grey as
    // drawn, it drowns on white in the light theme — black there, like buds
    Component {
        id: catC
        AnimatedImage {
            width: 44
            height: 26
            source: "runcat.gif"
            mipmap: true
            speed: 1 + 4 * SysStats.cpu
            layer.enabled: Skin.light
            layer.effect: MultiEffect { brightness: -1 }
        }
    }
    Binding { target: SysStats; property: "cat"; value: Skin.state.bar.includes("cat") }
    // network: two arcs and a dot, round caps like the battery; off — a slash
    Component {
        id: wifiC
        Shape {
            id: wf
            width: 20
            height: 18
            preferredRendererType: Shape.CurveRenderer
            readonly property color ink: root.wifi?.connected ? Skin.fg : Skin.grey
            ShapePath {
                strokeColor: wf.ink; strokeWidth: 2.2; capStyle: ShapePath.RoundCap; fillColor: "transparent"
                PathAngleArc { centerX: 10; centerY: 15; radiusX: 5.5; radiusY: 5.5; startAngle: 220; sweepAngle: 100 }
                PathAngleArc { centerX: 10; centerY: 15; radiusX: 10.5; radiusY: 10.5; startAngle: 220; sweepAngle: 100 }
            }
            ShapePath {
                strokeColor: Networking.wifiEnabled ? "transparent" : wf.ink; strokeWidth: 2.2; capStyle: ShapePath.RoundCap
                startX: 3; startY: 2
                PathLine { x: 17; y: 17 }
            }
            ShapePath {
                strokeWidth: -1; fillColor: wf.ink
                PathAngleArc { centerX: 10; centerY: 15; radiusX: 1.9; radiusY: 1.9; startAngle: 0; sweepAngle: 360 }
            }
        }
    }
    Component {
        id: btC
        Icon {
            text: Bluetooth.defaultAdapter?.enabled ? "\u{F00AF}" : "\u{F00B2}"
            color: Bluetooth.devices.values.some(d => d.connected) ? Skin.fg : Skin.grey
        }
    }
    Component {
        id: soundC
        Icon {
            text: Sys.muted ? "\u{F075F}" : "\u{F057E}"
            Notch { onNotch: d => Sys.setVol(Sys.vol + d * 0.05) }
        }
    }
    Component {
        id: notesC
        Icon {
            text: Skin.state.dnd ? "\u{F009B}" : "\u{F009A}"
            color: Notes.list.length ? Skin.fg : Skin.grey
        }
    }
    // on the side the battery stands, charge climbs from the bottom; on top it lies down and grows leftward. charging —
    // the bolt first, the fill breathes while it charges
    Component {
        id: batC
        Pile {
            id: batc
            HoverHandler { onHoveredChanged: { root.batHot = hovered; root.peek(batc); } Component.onDestruction: root.batHot = false }
            spacing: 8
            readonly property bool ac: !UPower.onBattery
            readonly property bool charging: root.bat.state === UPowerDeviceState.Charging
            // the breathing steps at 20 fps, like the orb in home/Back: a plain animation would drive the bar on every
            // vsync (120 hz) through the whole charge. a cosine with a 2.2 s period — the same two InOutSines of 1.1 s
            property real phase: 0
            readonly property real pulse: charging ? 0.675 + 0.325 * Math.cos(phase * Math.PI / 1.1) : 1
            Timer { running: batc.charging; interval: 50; repeat: true; onTriggered: batc.phase = (batc.phase + 0.05) % 2.2; onRunningChanged: batc.phase = 0 }
            Icon { visible: batc.ac; text: "\u{F140B}"; font.pixelSize: 14 }
            Rectangle {
                width: root.vert ? 14 : 26
                height: root.vert ? 26 : 14
                radius: 7
                color: "transparent"
                border { width: 1.5; color: Skin.grey }
                Rectangle {
                    x: 3
                    y: parent.height - 3 - height
                    width: root.vert ? parent.width - 6 : (parent.width - 6) * root.bat.percentage
                    height: root.vert ? (parent.height - 6) * root.bat.percentage : parent.height - 6
                    radius: 4
                    color: root.batLow ? Skin.red : Skin.fg
                    opacity: batc.pulse
                }
            }
            // width sized for "100": on top the tray hugs the right edge, 99 → 100 would shove everything left
            Lb { width: full.implicitWidth; horizontalAlignment: Text.AlignHCenter; text: Math.round(root.bat.percentage * 100); px: 10 }
            Lb { id: full; visible: false; text: "100"; px: 10 }
        }
    }
    // power mode as ticks (Rules.modes): ultra lights one, performance all; click — the next one,
    // hover (on the battery too) — the card with the full picker
    Component {
        id: modeC
        Item {
            id: ticks
            width: 40
            height: 22
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: Rules.modeCount
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 5 + index * 3
                        radius: 1.5
                        color: index <= Rules.mode ? Skin.fg : Skin.s3
                    }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: { root.tickHot = hovered; root.peek(ticks); } Component.onDestruction: root.tickHot = false }
            TapHandler { onTapped: Rules.setMode((Rules.mode + 1) % Rules.modeCount) }
        }
    }
    Component {
        id: powerC
        Icon {
            text: "\u{F0425}"
            color: pwr.hovered ? Skin.fg : Skin.grey
            HoverHandler { id: pwr; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.powerClicked() }
        }
    }

    // ---- battery and power mode: hover the battery or the ticks and a card opens beside the bar toward the screen, like a
    // caelestia popover. charge in doto, status, a scale; below, the modes as circles with ticks — click to pick, what's
    // under the cursor shows what it does. leave both the bar and the card — it fades ----
    property bool batHot: false
    property bool tickHot: false
    readonly property bool powHot: batHot || tickHot || popHov.hovered
    readonly property bool batLow: UPower.onBattery && root.bat.percentage < 0.15
    // the card anchors to whatever is hovered (battery or ticks): on the side its bottom meets theirs, on top its right
    // edge meets theirs; once visible it stops jumping around
    property point popAt
    function peek(it) { if (!pop.visible) popAt = it.mapToItem(pill, it.width, it.height); }
    property bool powOpen: false
    property int powPeek: -1
    onPowHotChanged: powHot ? powOpenT.restart() : powCloseT.restart()
    Timer { id: powOpenT; interval: 180; onTriggered: if (root.powHot) root.powOpen = true }
    Timer { id: powCloseT; interval: 300; onTriggered: if (!root.powHot) root.powOpen = false }
    function hm(sec) { const m = Math.round(sec / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    readonly property string batState: root.bat.state === UPowerDeviceState.Charging
        ? "charging" + (root.bat.timeToFull ? ` · full in ${hm(root.bat.timeToFull)}` : "")
        : !UPower.onBattery ? "on ac · full"
        : "on battery" + (root.bat.timeToEmpty ? ` · ${hm(root.bat.timeToEmpty)} left` : "")

    PopupWindow {
        id: pop
        property real t: root.powOpen ? 1 : 0
        Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
        visible: t > 0
        // off the bar pill's inner edge with a 14 gap; on the side it grows up from popAt, on top down and to the left
        anchor.item: pill
        anchor.rect: root.vert ? Qt.rect(pill.width + 14, root.popAt.y, 1, 1) : Qt.rect(root.popAt.x, pill.height + 14, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: root.vert ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Left
        implicitWidth: Math.ceil(440 * Skin.s)
        implicitHeight: Math.ceil(card.height * Skin.s)
        color: "transparent"

        Stage {
            Rectangle {
                id: card
                width: 440
                height: body.height + 52
                radius: Skin.corner(36)
                color: Skin.s1
                border { width: 1; color: Skin.s2 }
                opacity: pop.t
                transform: Translate { x: root.vert ? -16 * (1 - pop.t) : 0; y: root.vert ? 0 : -16 * (1 - pop.t) }
                HoverHandler { id: popHov }

                Column {
                    id: body
                    x: 26
                    y: 26
                    width: parent.width - 52
                    spacing: 18

                    Row {
                        spacing: 14
                        Num { text: Math.round(root.bat.percentage * 100); font.pixelSize: 72 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Lb { text: "% battery"; color: Skin.fg }
                            Lb { text: root.batState }
                        }
                    }
                    Seg { width: parent.width; height: 6; n: 24; f: root.bat.percentage; on: root.batLow ? Skin.red : Skin.fg }

                    Lb { topPadding: 6; text: "power mode" }
                    Row {
                        spacing: (body.width - Rules.modeCount * 80) / Math.max(1, Rules.modeCount - 1)
                        Repeater {
                            model: Rules.modeCount
                            Column {
                                id: mo
                                required property int index
                                readonly property bool on: Rules.mode === index
                                spacing: 10
                                Rectangle {
                                    width: 80
                                    height: 80
                                    radius: 40
                                    color: mo.on ? Skin.fg : moHov.hovered ? Skin.s3 : Skin.s2
                                    Behavior on color { ColorAnimation { duration: Skin.t } }
                                    // ticks: the more lit, the stronger the mode
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                required property int index
                                                anchors.bottom: parent.bottom
                                                width: 5
                                                height: 8 + index * 6
                                                radius: 2.5
                                                color: index <= mo.index ? (mo.on ? Skin.ink : Skin.fg) : (mo.on ? Skin.mute : Skin.s3)
                                            }
                                        }
                                    }
                                    HoverHandler {
                                        id: moHov
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: if (hovered) root.powPeek = mo.index; else if (root.powPeek === mo.index) root.powPeek = -1
                                    }
                                    TapHandler { onTapped: Rules.setMode(mo.index) }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: mo.index === 3 ? "max" : Rules.modes[mo.index].name; color: mo.on ? Skin.fg : Skin.grey }
                            }
                        }
                    }
                    Lb {
                        readonly property int i: root.powPeek >= 0 ? root.powPeek : Rules.mode
                        width: parent.width
                        elide: Text.ElideRight
                        text: `${Rules.modes[i].what} · ${i === 0 ? Rules.rates[0] : Rules.refreshHz} hz`
                    }
                }
            }
        }
    }
}
