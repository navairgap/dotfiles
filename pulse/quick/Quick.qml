import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.components
import qs.settings
import qs.services

// quick settings: super+a or a tray click. a 470 panel at the right edge, pinned to the bottom, sliding in from the side: clock,
// wifi/bluetooth pills, round tiles, sliders (filled side is a white pill, empty side is dots), mini player, notifications. windows behind dim to 35%
PanelWindow {
    id: root

    signal powerRequested
    signal settingsRequested

    property bool open: false
    // peeked — opened by hovering the right edge (hot): takes no keyboard, and once the cursor leaves the panel it closes itself
    property bool peeked: false
    function toggle() { peeked = false; open = !open; }
    function close() { open = false; }
    // a click inside pins the panel: from then on it closes the usual ways (esc, outside click) and hover no longer decides
    function pin() { peeked = false; }
    function peek() {
        if (open) return;
        peeked = true;
        open = true;
    }
    // the open list: "wifi" | "bt" under the pills (picker), "rec" under the tiles (rec), "" — nothing
    property string pick: ""
    onOpenChanged: if (open) Sys.earRun([]); else pick = ""
    // cursor away from the panel and the hot strip for 500ms — close. the seen handler: hyprland won't report the cursor on a fresh
    // surface until the mouse moves, so until the first motion nobody knows where it is and the panel waits (otherwise it opened
    // under a still cursor and shut right away)
    Timer { interval: 500; running: root.open && root.peeked && seen.hovered && !keep.hovered && !edge.hovered; onTriggered: root.close() }

    property real t: open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && !peeked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-quick"

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var net: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDev: Bluetooth.devices.values.find(d => d.connected) ?? null
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35 * root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        HoverHandler { id: seen }
        // hover zone: the panel plus a strip out to the screen edge — a cursor at the very edge doesn't count as gone, or the
        // panel would close and instantly reopen. the panel sits inside the zone, not next to it: a button's hoverhandler (mode
        // cells, picker rows) mutes hover on the sibling it covers, but not on an ancestor
        Item {
            anchors { right: parent.right; bottom: parent.bottom }
            width: panel.width + panel.anchors.rightMargin
            height: panel.height + 14
            HoverHandler { id: keep }
            Rectangle {
                id: panel
                anchors { right: parent.right; rightMargin: 14 - 24 * (1 - root.t); bottom: parent.bottom; bottomMargin: 14 }
                width: 470
                height: col.height + 44
                opacity: root.t
                radius: Skin.corner(36)
                color: Skin.s1
                border { width: 1; color: Skin.s2 }
                focus: true
                Keys.onEscapePressed: root.close()
                MouseArea { anchors.fill: parent } // a click on the panel doesn't close it

                Column {
                    id: col
                    x: 22
                    y: 22
                    width: parent.width - 44
                    spacing: 16

                    Item {
                        width: parent.width
                        height: 54
                        Row {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Num { anchors.verticalCenter: parent.verticalCenter; text: `${Skin.hh(clock.date)}:${Qt.formatTime(clock.date, "mm")}`; font.pixelSize: 44 }
                            Lb { anchors.verticalCenter: parent.verticalCenter; text: Qt.locale("en_US").toString(clock.date, "ddd d MMM") }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            spacing: 14
                            Round { icon: "\u{F0493}"; onClicked: { root.close(); root.settingsRequested(); } } // settings; other shells keep theirs in their SHELL
                            Round { icon: "\u{F0425}"; onClicked: { root.close(); root.powerRequested(); } }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 12
                        Pill {
                            on: Networking.wifiEnabled
                            icon: on ? "\u{F05A9}" : "\u{F05AA}"
                            name: "Wi-Fi"
                            sub: !on ? "off" : (Networking.connectivity === NetworkConnectivity.Portal ? "sign in · " : "") + (root.net?.name ?? "no network")
                            picked: root.pick === "wifi"
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            onMenu: root.pick = picked ? "" : "wifi"
                        }
                        Pill {
                            on: root.bt?.enabled ?? false
                            icon: on ? "\u{F00AF}" : "\u{F00B2}"
                            name: "Bluetooth"
                            sub: !on ? "off" : root.btDev?.name ?? "on"
                            picked: root.pick === "bt"
                            onClicked: if (root.bt) root.bt.enabled = !root.bt.enabled
                            onMenu: root.pick = picked ? "" : "bt"
                        }
                    }

                    Picker { width: parent.width; kind: root.pick; onTouched: root.pin() }

                    // nothing / cmf earbuds (sys.ear): name and charge, anc below as cells like the power modes
                    Column {
                        visible: !!Sys.ear
                        width: parent.width
                        spacing: 10
                        Item {
                            width: parent.width
                            height: 20
                            Lb { x: 6; text: Sys.buds?.name ?? "" }
                            Lb {
                                anchors.right: parent.right
                                rightPadding: 6
                                text: ["l", "r", "case"].filter(k => Sys.ear?.[k] !== undefined).map(k => `${k} ${Sys.ear[k]}`).join(" · ")
                                color: Skin.fg
                            }
                        }
                        Rectangle {
                            id: anc
                            width: parent.width
                            height: 54
                            radius: Skin.corner(27)
                            color: Skin.s2
                            readonly property real cell: (width - 12) / Sys.ancModes.length
                            readonly property int at: Sys.ancModes.findIndex(m => m[0] === Sys.ear?.mode)
                            Rectangle {
                                visible: anc.at >= 0
                                x: 6 + anc.cell * anc.at
                                y: 6
                                width: anc.cell
                                height: parent.height - 12
                                radius: height / 2
                                color: Skin.fg
                                Behavior on x { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                            }
                            Repeater {
                                model: Sys.ancModes
                                Item {
                                    id: am
                                    required property var modelData
                                    required property int index
                                    x: 6 + anc.cell * index
                                    width: anc.cell
                                    height: anc.height
                                    Lb { anchors.centerIn: parent; text: am.modelData[1]; color: anc.at === am.index ? Skin.ink : Skin.grey }
                                    TapHandler { onTapped: { root.pin(); Sys.setAnc(am.modelData[0]); } }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 4
                        rowSpacing: 14
                        Tile { icon: "\u{F009B}"; name: "dnd"; on: Skin.state.dnd; onClicked: Skin.state.dnd = !Skin.state.dnd }
                        Tile { icon: "\u{F0594}"; name: "night"; on: Sys.night; onClicked: Sys.toggleNight() }
                        Tile { icon: "\u{F001D}"; name: "airplane"; on: Sys.air; onClicked: Sys.toggleAir() }
                        Tile { icon: "\u{F0176}"; name: "caffeine"; on: Sys.caffeine; onClicked: Sys.caffeine = !Sys.caffeine }
                        Tile { icon: on ? "\u{F036C}" : "\u{F036D}"; name: "mic"; on: Sys.micOn; onClicked: Sys.toggleMic() }
                        Tile { icon: "\u{F044A}"; name: "record"; on: Sys.rec; picked: root.pick === "rec"; onClicked: { root.close(); Sys.toggleRec(); } onMenu: root.pick = picked ? "" : "rec" }
                        Tile { icon: "\u{F0483}"; name: "vpn"; on: Sys.vpn; onClicked: Sys.toggleVpn() }
                        Tile { icon: "\u{F050E}"; name: "dark"; on: !Skin.light; onClicked: Skin.setLight(!Skin.light) }
                    }

                    Rec { width: parent.width; visible: root.pick === "rec"; onTouched: root.pin(); onStart: { root.close(); Sys.toggleRec(); } }

                    Slider { icon: "\u{F00E0}"; visible: Sys.hasBri; value: Sys.bri; onMoved: v => Sys.setBri(v) }
                    Slider { icon: Sys.muted ? "\u{F075F}" : "\u{F057E}"; value: Sys.muted ? 0 : Sys.vol; onMoved: v => Sys.setVol(v) }

                    // power modes: four cells, the white fill slides over to the chosen one; the notches are the strength.
                    // ultra also runs 60hz and drops animations, blur and shadows (rules.modes)
                    // game mode on the right (rules.store.game): no animations, blur, shadows or gaps, and tearing
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            id: modes
                            width: parent.width - game.width - 12
                            height: 54
                            radius: Skin.corner(27)
                            color: Skin.s2
                            readonly property real cell: (width - 12) / Rules.modeCount
                            Rectangle {
                                x: 6 + modes.cell * Rules.mode
                                y: 6
                                width: modes.cell
                                height: parent.height - 12
                                radius: height / 2
                                color: Skin.fg
                                Behavior on x { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                            }
                            Repeater {
                                model: Rules.modeCount
                                Item {
                                    id: mc
                                    required property int index
                                    readonly property bool on: Rules.mode === index
                                    x: 6 + modes.cell * index
                                    width: modes.cell
                                    height: modes.height
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 10
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Repeater {
                                                model: 4
                                                Rectangle {
                                                    required property int index
                                                    anchors.bottom: parent.bottom
                                                    width: 4
                                                    height: 6 + index * 4
                                                    radius: 2
                                                    color: index <= mc.index ? (mc.on ? Skin.ink : Skin.fg) : (mc.on ? Skin.mute : Skin.s3)
                                                }
                                            }
                                        }
                                        Lb { anchors.verticalCenter: parent.verticalCenter; text: Rules.modes[mc.index].short; color: mc.on ? Skin.ink : Skin.grey }
                                    }
                                    TapHandler { onTapped: { root.pin(); Rules.setMode(mc.index); } }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                        Rectangle {
                            id: game
                            width: 54
                            height: 54
                            radius: 27
                            color: Rules.store.game ? Skin.fg : Skin.s2
                            Behavior on color { ColorAnimation { duration: Skin.t } }
                            Icon { anchors.centerIn: parent; text: "\u{F0297}"; font.pixelSize: 22; color: Rules.store.game ? Skin.ink : Skin.fg }
                            TapHandler { onTapped: { root.pin(); Rules.store.game = !Rules.store.game; } }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // mini player
                    Rectangle {
                        visible: !!Media.player
                        width: parent.width
                        height: 86
                        radius: Skin.corner(30)
                        color: Skin.s2
                        Art { id: mart; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; height: 62; step: 4; url: Media.player?.trackArtUrl ?? "" }
                        Column {
                            anchors { left: mart.right; leftMargin: 16; right: mctl.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: Media.player?.trackTitle || "Nothing on"; font { family: Skin.ui; pixelSize: 16; weight: Font.DemiBold } color: Skin.fg }
                            Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: Media.player?.trackArtist ?? ""; font { family: Skin.ui; pixelSize: 13 } color: Skin.grey }
                        }
                        Controls { id: mctl; anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter } size: 20; play: 44 }
                    }

                    Item {
                        width: parent.width
                        height: 20
                        Lb { x: 6; text: `notifications · ${Notes.list.length}` }
                        Lb {
                            anchors.right: parent.right
                            rightPadding: 6
                            visible: Notes.list.length > 0
                            text: "clear all"
                            color: Skin.fg
                            TapHandler { onTapped: { root.pin(); Notes.clear(); } }
                        }
                    }

                    // notification cards, newest on top; whatever doesn't fit scrolls
                    ListView {
                        id: notes
                        width: parent.width
                        height: Math.min(shown, stage.height - 28 - 44 - y)
                        // animate with the content (clear all, dismiss); cap it at once: picker or player above must not push the header off screen
                        property real shown: contentHeight
                        Behavior on shown { enabled: Rules.moving; NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
                        clip: true
                        spacing: 10
                        model: Notes.list.slice().reverse()
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            readonly property var n: modelData
                            width: notes.width
                            height: body.height + 32
                            radius: Skin.corner(26)
                            color: Skin.s2
                            border { width: n.urgency === NotificationUrgency.Critical ? 1 : 0; color: Skin.red }

                            Rectangle {
                                x: 18
                                y: 16
                                width: 42
                                height: 42
                                radius: 21
                                color: Skin.s3
                                Icon { anchors.centerIn: parent; text: "\u{F009A}"; visible: !nicon.visible }
                                Image {
                                    id: nicon
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    visible: status === Image.Ready
                                    source: n.appIcon ? Quickshell.iconPath(n.appIcon, true) : ""
                                    sourceSize: Qt.size(24, 24)
                                    layer.enabled: true
                                    layer.effect: Dm { step: 2 }
                                }
                            }
                            Column {
                                id: body
                                x: 74
                                y: 16
                                width: parent.width - x - 18
                                Lb { width: parent.width; elide: Text.ElideRight; text: `${n.appName || "app"} · ${Notes.ago(n, clock.date.getTime())}`; px: 11 }
                                Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: n.summary; font { family: Skin.ui; pixelSize: 15; weight: Font.DemiBold } color: Skin.fg }
                                Text {
                                    width: parent.width
                                    visible: !!n.body
                                    topPadding: 2
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: n.body
                                    font { family: Skin.ui; pixelSize: 14 }
                                    color: Skin.grey
                                }
                            }
                            // tap — the default action (if any) and the card goes away. invoke() closes the notification itself, taking
                            // this card with it — after that only my captured reference works, and dismiss only if it's still alive
                            TapHandler {
                                onTapped: {
                                    root.pin();
                                    const it = n;
                                    it.actions.find(a => a.identifier === "default")?.invoke();
                                    if (it.tracked) it.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // the hot strip: the panel sits over it, cursor on the strip holds the panel open, same as the panel itself
    Item {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 2
        height: Math.round(parent.height * 0.8)
        HoverHandler { id: edge }
    }

    // round button in the header
    component Round: Rectangle {
        property string icon
        signal clicked
        width: 44
        height: 44
        radius: 22
        color: Skin.s2
        Icon { anchors.centerIn: parent; text: parent.icon }
        TapHandler { onTapped: { root.pin(); parent.clicked(); } }
    }
    // pill: on is white with dark text. right click opens the network/device list, the chevron shows whether it's open
    component Pill: Rectangle {
        id: pill
        property bool on
        property bool picked
        signal menu
        property string icon
        property string name
        property string sub
        signal clicked
        width: (col.width - 12) / 2
        height: 76
        radius: Skin.corner(38)
        color: on ? Skin.fg : Skin.s2
        Behavior on color { ColorAnimation { duration: Skin.t } }
        Rectangle {
            id: pi
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            height: 52
            radius: 26
            color: pill.on ? Skin.ink : Skin.s3
            Icon { anchors.centerIn: parent; text: pill.icon; font.pixelSize: 22 }
        }
        Column {
            anchors { left: pi.right; leftMargin: 12; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            Text { text: pill.name; font { family: Skin.ui; pixelSize: 16; weight: Font.DemiBold } color: pill.on ? Skin.ink : Skin.fg }
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: pill.sub
                font { family: Skin.mono; pixelSize: 11; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                color: pill.on ? Skin.ink : Skin.fg
                opacity: 0.6
            }
        }
        Icon {
            id: chev
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            text: "\u{F0140}"
            font.pixelSize: 18
            color: pill.on ? Skin.ink : Skin.fg
            opacity: pill.picked ? 1 : 0.4
            rotation: pill.picked ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
        }
        TapHandler { onTapped: { root.pin(); pill.clicked(); } }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.pin(); pill.menu(); } }
    }
    // round tile, 68: on is a white circle. right click — menu (record opens the rec settings), label goes white while it's open
    component Tile: Column {
        id: tile
        property bool on
        property bool picked
        signal menu
        property string icon
        property string name
        signal clicked
        width: col.width / 4
        spacing: 8
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 68
            height: 68
            radius: 34
            color: tile.on ? Skin.fg : Skin.s2
            Behavior on color { ColorAnimation { duration: Skin.t } }
            Icon { anchors.centerIn: parent; text: tile.icon; font.pixelSize: 24; color: tile.on ? Skin.ink : Skin.fg }
            TapHandler { onTapped: { root.pin(); tile.clicked(); } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.pin(); tile.menu(); } }
        }
        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: tile.name; px: 10; color: tile.picked ? Skin.fg : Skin.grey }
    }
    // slider: the filled part is a white pill with the icon, the empty part a row of dots
    component Slider: Rectangle {
        id: sl
        property real value
        property string icon
        signal moved(real v)
        readonly property real shown: area.pressed ? area.v : value
        width: col.width
        height: 54
        radius: Skin.corner(27)
        color: Skin.s2
        // empty side — dots on an 11px pitch. not a tiled svg: it rasterizes to 11px and blurs with the canvas scale
        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11 - 2.8
            Repeater {
                model: Math.max(0, Math.floor((sl.width - 20) / 11) + 1)
                Rectangle { width: 2.8; height: 2.8; radius: 1.4; color: Skin.mute }
            }
        }
        Rectangle {
            width: Math.max(height, sl.width * sl.shown)
            height: parent.height
            radius: Skin.corner(27)
            color: Skin.fg
            Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; text: sl.icon; font.pixelSize: 21; color: Skin.ink }
        }
        Rectangle {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: val.width + 16
            height: val.height + 8
            radius: Skin.corner(10)
            color: Skin.s2
            Lb { id: val; anchors.centerIn: parent; text: Math.round(sl.shown * 100) }
        }
        MouseArea {
            id: area
            property real v
            property real wacc: 0
            anchors.fill: parent
            preventStealing: true
            function set(x) { v = Math.max(0, Math.min(1, x / width)); sl.moved(v); }
            // pin on release: a peeked panel taking the keyboard (none → exclusive) makes hyprland drop every mouse button —
            // the first drag after peek used to die right at the click point
            onPressed: e => set(e.x)
            onPositionChanged: e => set(e.x)
            onReleased: root.pin()
            // wheel: 5% a notch, touchpad (it reports a scroll phase, a wheel doesn't) four times slower or a swipe covers half the scale.
            // i accumulate up to 2%: brightness rounding eats the tiny touchpad steps, and every one of them would spawn a brightnessctl.
            // no pin: scrolling isn't a click, a peeked panel closes itself and takes no keyboard. the direction follows the fingers,
            // like qt's slider: natural scroll (inverted) doesn't flip it, rightward and toward me — more
            onWheel: e => {
                wacc += (e.inverted ? -1 : 1) * (e.angleDelta.y || -e.angleDelta.x) / 120 * 0.05 * (e.phase === Qt.NoScrollPhase ? 1 : 0.25);
                if (Math.abs(wacc) < 0.02)
                    return;
                sl.moved(Math.max(0, Math.min(1, sl.shown + wacc)));
                wacc = 0;
            }
        }
    }
}
