import QtQuick

// pulse for sddm: a dial like the mode wheel on a camera, with a glyph tachometer inside. the centre sits on
// the bottom edge of the screen, so only the top half shows — the scale is a speedometer semicircle.
// boot is staged like a car dashboard: red dot, the knurl walks the circle, glyphs sweep to the limit and the
// needle back and forth (self-test), then clock and sessions. behind the knurl on the left, a step log.
// password letters rev the needle, enter pins it at the redline while pam thinks; wrong password — red flash and the needle drops.
// ←→ or the mouse wheel spin the dial (session), tab — next user, shift+tab or a click on the name — type your own,
// esc — wipe it.
// ↑ opens the second ring, power, on the right: ←→ to pick, enter to run it, ↓ or esc — back, any letter — back to the password
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: bg

    readonly property color bg: "#000000"
    readonly property color s2: "#1A1A1A"
    readonly property color s3: "#2A2A2A"
    readonly property color mute: "#4A4A4A"
    readonly property color grey: "#8C8C8C"
    readonly property color fg: "#F2F2F2"
    readonly property color red: "#D71921"

    FontLoader { id: doto; source: "fonts/Doto[ROND,wght].ttf" }
    FontLoader { id: grotesk; source: "fonts/SpaceGrotesk-Regular.otf" }
    FontLoader { id: mono; source: "fonts/SpaceMono-Regular.ttf" }

    property date now: new Date()
    property bool blink: true
    Timer { running: true; repeat: true; interval: 500; onTriggered: { root.blink = !root.blink; root.now = new Date(); } }

    // ---- power-on: steps in order ----
    property real knurl: 0 // the knurl: how much of the circle it has walked
    property real test: 0  // self-test: glyphs and needle up to the limit and back
    property real face: 0  // clock, sessions, name
    property int step: 0   // how many log steps are done
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 350 }
        NumberAnimation { target: root; property: "knurl"; to: 1; duration: 700; easing.type: Easing.InOutSine }
        PropertyAction { target: root; property: "step"; value: 1 }
        NumberAnimation { target: root; property: "test"; to: 1; duration: 650; easing.type: Easing.OutCubic }
        PropertyAction { target: root; property: "step"; value: 2 }
        PauseAnimation { duration: 150 }
        NumberAnimation { target: root; property: "test"; to: 0; duration: 600; easing.type: Easing.InOutCubic }
        PropertyAction { target: root; property: "step"; value: 3 }
        NumberAnimation { target: root; property: "face"; to: 1; duration: 500; easing.type: Easing.OutQuart }
        PropertyAction { target: root; property: "step"; value: 4 }
    }

    // ---- tachometer ----
    readonly property int n: 32 // glyphs on the scale, one per letter
    property bool busy: false
    property bool ok: false
    property bool flash: false
    property bool fail: false
    property real wave: 0
    NumberAnimation on wave { running: root.busy; from: 0; to: 1; duration: 600; loops: Animation.Infinite }
    // where the needle is pulled; it catches up on a spring, overshooting like a real one. the target must not
    // change every frame: the behavior would restart the spring mid-step and the needle would freeze. so the
    // self-test (step < 3) runs without the spring, and the redline jitter is added to the angle, not the target
    readonly property real level: ok ? 1 : busy ? 0.94 : Math.max(test, Math.min(pwd.text.length / n, 1))
    property real needle: level
    Behavior on needle { enabled: root.step >= 3; SpringAnimation { spring: 4; damping: 0.26; epsilon: 0.002 } }
    function deg(v) { return -84 + 168 * v; } // 0…1 → angle from 12 o'clock, clockwise; the semicircle hangs over the screen edge

    SequentialAnimation {
        id: denied
        loops: 3
        PropertyAction { target: root; property: "flash"; value: true }
        PauseAnimation { duration: 110 }
        PropertyAction { target: root; property: "flash"; value: false }
        PauseAnimation { duration: 90 }
    }

    // ---- session: dial position ----
    property int si: sessionModel.lastIndex
    readonly property real gap: 22 // degrees between sessions on the dial
    property real rot: -si * gap
    Behavior on rot { SpringAnimation { spring: 5; damping: 0.35 } }
    function turn(d) { if (labels.count) si = (si + d + labels.count) % labels.count; }

    // ---- second ring: power. pm is the keyboard's pick, -1 means the ring isn't selected ----
    readonly property var power: [
        { t: "sleep", a: 37, can: sddm.canSuspend, go: () => sddm.suspend() },
        { t: "reboot", a: 52, can: sddm.canReboot, go: () => sddm.reboot() },
        { t: "power off", a: 68, can: sddm.canPowerOff, go: () => sddm.powerOff() }
    ]
    property int pm: -1
    // the next enabled entry from i in direction d; none — i stays
    function next(i, d) {
        for (let j = i + d; j >= 0 && j < power.length; j += d) if (power[j].can) return j;
        return i;
    }
    // ring arrows and enter, shared by both fields. true = the key is eaten, the field never sees it
    function key(e) {
        if (pm >= 0) {
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) pm = next(pm, e.key === Qt.Key_Right ? 1 : -1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { const p = power[pm]; pm = -1; p.go(); } // woke up — the ring is released, so enter wakes instead of putting it back to sleep
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Escape) pm = -1;
            else if (e.key !== Qt.Key_Up) { pm = -1; return false; } // typing — back to the password, the letter goes to the field
            return true;
        }
        if (e.key === Qt.Key_Up) { pm = next(-1, 1); return pm >= 0; }
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) { turn(e.key === Qt.Key_Right ? 1 : -1); return true; }
        return false;
    }

    // ---- who's logging in: the name is a field, sddm's list only fills it (tab). any name can be typed, hidden ones too ----
    property int ui: Math.max(0, userModel.lastIndex)
    function pick(d) {
        if (!names.count) return;
        ui = (ui + d + names.count) % names.count;
        user.text = names.itemAt(ui).name;
    }
    Component.onCompleted: {
        if (!user.text && names.count) user.text = names.itemAt(ui).name; // sddm forgot the last user — take the first in the list
        (user.text ? pwd : user).forceActiveFocus();
    }

    property bool queued: false
    property string msg // what pam said: faillock's "locked after 3 attempts"
    function login() {
        if (busy || ok) return;
        const who = user.text.trim();
        if (!who) { user.forceActiveFocus(); return; }
        if (step < 4) { queued = true; return; } // enter during the self-test — log in the moment it ends
        queued = false;
        busy = true;
        fail = false;
        msg = "";
        sddm.login(who, pwd.text, si);
    }
    onStepChanged: if (step === 4 && queued) login()
    Connections {
        target: sddm
        function onLoginFailed() { root.busy = false; root.fail = true; pwd.text = ""; denied.restart(); }
        function onLoginSucceeded() { root.busy = false; root.ok = true; }
        function onInformationMessage(m) { root.msg = m; }
    }

    // label: space mono caps, .14em tracking, grey
    component Lb: Text {
        property real px: 12
        font { family: mono.name; pixelSize: px; letterSpacing: px * 0.14; capitalization: Font.AllUppercase }
        color: root.grey
    }
    // text on an arc: letters on a circle of radius r, the middle one at angle a (degrees from 12 o'clock). space
    // mono is monospaced, so every letter steps the same. button = clickable (hit) and whitens under the mouse
    component Arc: Item {
        id: arc
        property string text
        property real r
        property real a
        property real px: 12
        property color color: root.grey
        property bool button: false
        property int hov: 0 // how many letters are hovered: leaving one and entering its neighbour arrive in any order
        signal hit
        readonly property string up: text.toUpperCase()
        FontMetrics { id: fm; font { family: mono.name; pixelSize: arc.px } }
        readonly property real adv: fm.advanceWidth("M") + px * 0.14
        Repeater {
            model: arc.up.split("")
            Text {
                required property string modelData
                required property int index
                readonly property real b: arc.a + (index + 0.5 - arc.up.length / 2) * arc.adv / arc.r * 180 / Math.PI
                x: arc.r * Math.sin(b * Math.PI / 180) - width / 2
                y: -arc.r * Math.cos(b * Math.PI / 180) - height / 2
                rotation: b
                text: modelData
                font { family: mono.name; pixelSize: arc.px }
                color: arc.button && arc.hov > 0 ? root.fg : arc.color
                MouseArea {
                    x: (parent.width - arc.adv) / 2
                    y: -8
                    width: arc.adv
                    height: parent.height + 16
                    enabled: arc.button
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: arc.hov += containsMouse ? 1 : -1
                    onClicked: arc.hit()
                }
            }
        }
    }
    // a dot on the circle of radius r at angle a (degrees from 12 o'clock), centred on the spot, turned along the radius
    component Polar: Rectangle {
        property real a
        property real r
        x: r * Math.sin(a * Math.PI / 180) - width / 2
        y: -r * Math.cos(a * Math.PI / 180) - height / 2
        rotation: a
    }

    // a 1920×1080 canvas, stretched over the screen
    Item {
        id: stage
        readonly property real s: Math.min(root.width / 1920, root.height / 1080)
        width: root.width / s
        height: root.height / s
        scale: s
        transformOrigin: Item.TopLeft
        opacity: root.ok ? 0 : 1
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 300 } NumberAnimation { duration: 500 } } }

        MouseArea {
            anchors.fill: parent
            property real acc: 0 // touchpads send tiny steps — accumulate up to a click
            onClicked: pwd.forceActiveFocus()
            onWheel: w => {
                acc += w.angleDelta.y;
                if (Math.abs(acc) < 120) return;
                root.turn(acc < 0 ? 1 : -1);
                acc = 0;
            }
        }

        Image {
            visible: config.boolValue("grid")
            anchors.fill: parent
            opacity: root.face
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="${root.s2}"/></svg>`)
        }

        // ---- the dial: everything measures from the centre ----
        Item {
            id: dial
            x: stage.width / 2
            y: stage.height

            // the rotating part: edge knurl and sessions
            Item {
                rotation: root.rot

                Repeater {
                    model: 240
                    Polar {
                        required property int index
                        // how far the front has passed this tick: the front sweeps the visible half from the left
                        // edge to the right
                        readonly property real d: root.knurl - ((index * 1.5 + root.rot) % 360 + 450) % 360 / 180
                        a: index * 1.5
                        r: 760
                        width: 2.5
                        height: 22
                        visible: d >= 0 || root.knurl >= 1
                        color: d < 0.06 && root.knurl < 1 ? root.fg : root.mute
                    }
                }
                Repeater {
                    id: labels
                    model: sessionModel
                    Arc {
                        required property int index
                        required property string name
                        readonly property real off: Math.abs(((a + root.rot) % 360 + 540) % 360 - 180) // from the mark, 0…180
                        a: index * root.gap
                        r: 712
                        px: 14
                        text: name
                        color: index === root.si ? root.fg : root.grey
                        opacity: root.face * Math.max(0, 1 - off / 80) * (root.pm < 0 ? 1 : 0.35)
                        button: opacity > 0.2
                        onHit: root.si = index
                    }
                }
            }

            // the dial's top mark, with the hint above it
            Rectangle { x: -2.5; y: -808; width: 5; height: 24; radius: 2.5; color: root.fg; opacity: root.knurl }
            Arc {
                r: 860
                px: 11
                color: root.mute
                opacity: root.face
                text: `←→ · session      ${root.next(-1, 1) >= 0 ? "↑ · power      " : ""}tab · user      enter · start`
            }

            // behind the knurl, on the arc: on the left the boot log reading bottom-up (step running — it blinks,
            // finished — ok) and the hostname; on the right the layout and power. power is always visible: when
            // it's not allowed (or --test-mode, where the daemon is absent and every can* is false) it's dim and unclickable
            Repeater {
                model: ["dial", "pulse", "needle", "auth"]
                Arc {
                    required property string modelData
                    required property int index
                    readonly property bool done: root.step > index
                    r: 845
                    a: -76 + index * 13
                    visible: root.step >= index
                    opacity: done || root.blink ? 1 : 0.4
                    text: `0${index + 1} ${modelData} · ${done ? (index === 3 ? "ready" : "ok") : "··"}`
                }
            }
            Arc { r: 845; a: -22; color: root.mute; opacity: root.face; text: sddm.hostName }
            Arc { r: 845; a: 22; color: root.mute; opacity: root.face; text: keyboard.layouts[keyboard.currentLayout]?.shortName ?? "" }
            Repeater {
                model: root.power
                Arc {
                    required property var modelData
                    required property int index
                    r: 845
                    a: modelData.a
                    button: modelData.can
                    color: !button ? root.mute : root.pm === index ? root.fg : root.grey
                    opacity: root.face
                    text: modelData.t
                    onHit: modelData.go()
                }
            }
            // the second ring's mark: outside the pick, rides like the dial's mark
            Polar {
                a: root.power[Math.max(0, root.pm)].a
                r: 885
                width: 4
                height: 16
                radius: 2
                color: root.fg
                opacity: root.pm >= 0 ? 1 : 0
                Behavior on a { SpringAnimation { spring: 5; damping: 0.35 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // the scale: capsule glyphs, lit up to the needle. redline — while pam thinks, a dip runs through them
            Repeater {
                model: root.n
                Polar {
                    required property int index
                    readonly property bool lit: index < Math.round(root.needle * root.n)
                    readonly property bool dip: root.busy && Math.abs(index - root.wave * root.n) < 2
                    a: root.deg((index + 0.5) / root.n)
                    r: 610
                    width: 10
                    height: 36
                    radius: 5
                    visible: root.step >= 1 || root.test > 0
                    color: root.flash ? root.red : lit && !dip ? root.fg : root.s3
                    Behavior on color { ColorAnimation { duration: 90 } }
                }
            }
            Repeater {
                model: 5
                Lb {
                    required property int index
                    readonly property real a: root.deg(index / 4) * Math.PI / 180
                    x: 658 * Math.sin(a) - width / 2
                    y: -658 * Math.cos(a) - height / 2
                    px: 13
                    text: index * root.n / 4
                    opacity: root.face
                }
            }

            // seconds: an inner arc of dots, as wide as the scale
            Repeater {
                model: 60
                Polar {
                    required property int index
                    a: root.deg(index / 59)
                    r: 320
                    width: 5
                    height: 5
                    radius: 2.5
                    opacity: root.knurl
                    color: index === root.now.getSeconds() ? root.fg : index < root.now.getSeconds() ? root.mute : root.s2
                }
            }

            // the needle: from the seconds ring up to the scale, red tip
            Item {
                rotation: root.deg(root.needle + (root.busy ? 0.015 * Math.sin(root.wave * 4 * Math.PI) : 0))
                opacity: root.step >= 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Rectangle {
                    x: -2
                    y: -578
                    width: 4
                    height: 230
                    radius: 2
                    color: root.fg
                    Rectangle { width: 4; height: 44; radius: 2; color: root.red }
                }
            }

            // the first thing to light up
            Rectangle {
                x: -8; y: -200; width: 16; height: 16; radius: 8
                color: root.red
                opacity: 1 - root.face
                NumberAnimation on scale { from: 0; to: 1; duration: 300; easing.type: Easing.OutBack }
            }

            Row {
                x: -width / 2
                y: -262
                opacity: root.face
                Repeater {
                    // qt gives a bare "h" as 0…23 anyway — i count the 12-hour hour myself
                    model: [config.boolValue("clock24") ? Qt.formatTime(root.now, "hh") : String(root.now.getHours() % 12 || 12), ":", Qt.formatTime(root.now, "mm")]
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData
                        font { family: doto.name; pixelSize: 130; weight: Font.Black; variableAxes: ({ "ROND": 100, "wght": 900 }) }
                        topPadding: -0.175 * font.pixelSize
                        bottomPadding: topPadding
                        color: root.fg
                        opacity: index === 1 && !root.blink ? 0.2 : 1
                    }
                }
            }
            Lb {
                x: -width / 2
                y: -128
                px: 12
                text: Qt.locale("en_US").toString(root.now, "ddd · d MMM")
                opacity: root.face
            }

            // under the clock: who's logging in and what's going on
            Repeater { id: names; model: userModel; Item { required property string name } } // logins for tab
            TextInput {
                id: user
                x: -width / 2
                y: -98
                width: 360
                height: 30
                opacity: root.face
                text: userModel.lastUser
                horizontalAlignment: TextInput.AlignHCenter
                font { family: grotesk.name; pixelSize: 24 }
                color: root.fg
                selectionColor: root.s3
                selectedTextColor: root.fg
                Lb { anchors.centerIn: parent; visible: !parent.text; text: "user" }
                onActiveFocusChanged: if (activeFocus) selectAll() // typing starts by replacing the whole name
                onAccepted: pwd.forceActiveFocus()
                Keys.onPressed: e => {
                    if (root.pm < 0 && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) return; // the field is visible — arrows move the cursor, not the dial
                    if (root.key(e)) e.accepted = true;
                    else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { pwd.forceActiveFocus(); e.accepted = true; }
                }
            }
            Lb {
                x: -width / 2
                y: -52
                px: 12
                opacity: root.face
                color: root.flash || root.fail ? root.red : root.grey
                text: root.ok ? "welcome" : root.busy ? "ignition…" : root.fail ? root.msg || "denied · try again"
                    : root.pm >= 0 ? `enter · ${root.power[root.pm].t}      ↓ · back`
                    : user.activeFocus ? "type user · tab"
                    : pwd.text ? `${pwd.text.length} · enter to start` : "type password"
            }
        }

        // the input is a real textinput (layouts, ime), just invisible
        TextInput {
            id: pwd
            width: 1
            height: 1
            opacity: 0
            focus: true
            echoMode: TextInput.Password
            onTextEdited: root.fail = false
            onAccepted: root.login()
            // no caret in an invisible field — the arrows belong to the dial and the ring
            Keys.onPressed: e => {
                if (root.key(e)) e.accepted = true;
                else if (e.key === Qt.Key_Escape) { text = ""; e.accepted = true; }
                else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                    if (e.key === Qt.Key_Tab && names.count > 1) root.pick(1);
                    else user.forceActiveFocus(); // one in the list, or shift+tab — go type the name
                    e.accepted = true;
                }
            }
        }

        // top corners: brand on the left, indicators on the right — a dot burns while the lock is on
        Column {
            x: 44
            y: 36
            spacing: 6
            opacity: root.face
            Text {
                text: "PULSE"
                font { family: doto.name; pixelSize: 34; weight: Font.Black; variableAxes: ({ "ROND": 100, "wght": 900 }) }
                topPadding: -0.175 * font.pixelSize
                bottomPadding: topPadding
                color: root.fg
            }
            Lb { px: 11; text: "login" }
        }
        Row {
            anchors { right: parent.right; rightMargin: 44 }
            y: 40
            spacing: 28
            opacity: root.face
            Repeater {
                model: [["caps", keyboard.capsLock], ["num", keyboard.numLock]]
                Row {
                    required property var modelData
                    spacing: 10
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: parent.modelData[1] ? root.fg : root.s3 }
                    Lb { px: 11; text: parent.modelData[0]; color: parent.modelData[1] ? root.fg : root.grey }
                }
            }
        }

    }
}
