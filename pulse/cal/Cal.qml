import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// calendar and focus timer, opened by a click on the bar clock. a 440 panel next to the bar (screen side), centered
// across so it sits opposite the clock, sliding out from the bar. the month as a 7×6 grid (today — a white circle),
// arrows and ←→ page through, a click on the month jumps back to today. below it the timer: a dot ring fills
// clockwise, minute presets, start/pause (space too), reset. while it runs pulse fills the lower bar strip.
// esc or a click outside — close
PanelWindow {
    id: root

    property bool open: false
    function toggle() { open = !open; }
    function close() { open = false; }
    property int shift: 0 // months away from now
    onOpenChanged: if (open) shift = 0

    property real t: open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-cal"

    SystemClock { id: clock; precision: SystemClock.Hours }
    readonly property var en: Qt.locale("en_US")
    readonly property var month: new Date(clock.date.getFullYear(), clock.date.getMonth() + shift, 1)
    readonly property int lead: (month.getDay() + 6) % 7 // days of the old month before monday

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35 * root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        Rectangle {
            id: panel
            // the bar pill's inner edge (14 + 64) plus a 14 gap — slides out from the bar; across, centered where the clock is
            readonly property real off: 92 - 24 * (1 - root.t)
            readonly property bool onTop: Skin.state.barAt === "top"
            x: onTop ? (parent.width - width) / 2 : off
            y: onTop ? off : (parent.height - height) / 2
            width: 440
            height: col.height + 52
            opacity: root.t
            radius: Skin.corner(36)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) root.close();
                else if (e.key === Qt.Key_Left) root.shift--;
                else if (e.key === Qt.Key_Right) root.shift++;
                else if (e.key === Qt.Key_Space) Focus.toggle();
                else return;
                e.accepted = true;
            }
            MouseArea { anchors.fill: parent } // clicks on the panel don't close it

            Column {
                id: col
                x: 26
                y: 26
                width: parent.width - 52
                spacing: 18

                Item {
                    width: parent.width
                    height: 44
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Num { anchors.verticalCenter: parent.verticalCenter; text: root.en.standaloneMonthName(root.month.getMonth(), Locale.ShortFormat); font.pixelSize: 44 }
                        Lb { anchors.verticalCenter: parent.verticalCenter; text: root.month.getFullYear() }
                        TapHandler { onTapped: root.shift = 0 }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Round { icon: "\u{F0141}"; onClicked: root.shift-- }
                        Round { icon: "\u{F0142}"; onClicked: root.shift++ }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        Text {
                            required property string modelData
                            width: col.width / 7
                            height: 28
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font { family: Skin.mono; pixelSize: 11 }
                            color: Skin.grey
                        }
                    }
                    Repeater {
                        model: 42
                        Item {
                            id: day
                            required property int index
                            readonly property var d: new Date(root.month.getFullYear(), root.month.getMonth(), index - root.lead + 1)
                            readonly property bool own: d.getMonth() === root.month.getMonth()
                            readonly property bool today: d.toDateString() === clock.date.toDateString()
                            width: col.width / 7
                            height: 46
                            Rectangle { anchors.centerIn: parent; visible: day.today; width: 38; height: 38; radius: 19; color: Skin.fg }
                            Text {
                                anchors.centerIn: parent
                                text: day.d.getDate()
                                font { family: Skin.mono; pixelSize: 14 }
                                color: day.today ? Skin.ink : !day.own ? Skin.mute : day.index % 7 > 4 ? Skin.grey : Skin.fg
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Skin.s2 }

                Row {
                    spacing: 24
                    Item {
                        width: 164
                        height: 164
                        Ring { anchors.fill: parent; n: 44; dot: 5; f: Focus.f }
                        Column {
                            anchors.centerIn: parent
                            Num { anchors.horizontalCenter: parent.horizontalCenter; text: Focus.mmss(Focus.left); font.pixelSize: 38 }
                            Lb {
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 10
                                text: Focus.running ? "focus" : Focus.paused ? "paused" : "ready"
                                color: Focus.running ? Skin.fg : Skin.grey
                                px: 10
                            }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 16
                        Lb { text: "focus · min" }
                        Row {
                            spacing: 8
                            Repeater {
                                model: [15, 25, 45, 60]
                                Rectangle {
                                    id: chip
                                    required property int modelData
                                    readonly property bool on: Focus.minutes === modelData
                                    width: 44
                                    height: 44
                                    radius: 22
                                    color: on ? Skin.fg : chipHov.hovered ? Skin.s3 : Skin.s2
                                    Text { anchors.centerIn: parent; text: chip.modelData; font { family: Skin.mono; pixelSize: 13 } color: chip.on ? Skin.ink : Skin.fg }
                                    HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: Focus.set(chip.modelData) }
                                }
                            }
                        }
                        Row {
                            spacing: 10
                            Rectangle {
                                width: 146
                                height: 44
                                radius: Skin.corner(22)
                                color: Focus.running ? Skin.s2 : Skin.fg
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Icon { anchors.verticalCenter: parent.verticalCenter; text: Focus.running ? "\u{F03E4}" : "\u{F040A}"; color: Focus.running ? Skin.fg : Skin.ink }
                                    Lb {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Focus.running ? "pause" : Focus.paused ? "resume" : "start"
                                        color: Focus.running ? Skin.fg : Skin.ink
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: Focus.toggle() }
                            }
                            Round { icon: "\u{F0450}"; opacity: Focus.running || Focus.paused ? 1 : 0.4; onClicked: Focus.reset() }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Skin.s2 }

                Row {
                    spacing: 24
                    Num {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 40
                        text: root.swFormat(root.swMs)
                        font.pixelSize: 44
                        color: root.swRun ? Skin.fg : Skin.grey
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Rectangle {
                            width: 146
                            height: 44
                            radius: Skin.corner(22)
                            color: root.swRun ? Skin.s2 : Skin.fg
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Icon { anchors.verticalCenter: parent.verticalCenter; text: root.swRun ? "\u{F03E4}" : "\u{F040A}"; color: root.swRun ? Skin.fg : Skin.ink }
                                Lb { anchors.verticalCenter: parent.verticalCenter; text: root.swRun ? "stop" : "start"; color: root.swRun ? Skin.fg : Skin.ink }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.swToggle() }
                        }
                        Round { icon: "\u{F0450}"; opacity: root.swMs > 0 ? 1 : 0.4; onClicked: root.swReset() }
                    }
                    Lb { anchors.verticalCenter: parent.verticalCenter; text: "stopwatch"; px: 10; opacity: 0.6 }
                }
            }
        }
    }

    // stopwatch: self-contained, the focus timer owns its ring — this just counts up, centiseconds and all
    property bool swRun: false
    property real swAt: 0          // elapsed ms banked while paused
    property date swFrom: new Date()
    property int swTick: 0         // the display re-reads the clock on this; Date.now() alone isn't reactive
    Timer { running: swRun; interval: 173; repeat: true; onTriggered: swTick++ }
    readonly property real swMs: swAt + (swRun ? Date.now() - swFrom.getTime() : 0) + swTick * 0
    function swToggle() {
        const now = new Date();
        if (swRun) { swAt += now.getTime() - swFrom.getTime(); swRun = false; }
        else { swFrom = now; swRun = true; }
    }
    function swReset() { swRun = false; swAt = 0; }
    function swFormat(ms) {
        const cs = Math.floor(ms / 10) % 100, s = Math.floor(ms / 1000) % 60, m = Math.floor(ms / 60000);
        return `${m}:${String(s).padStart(2, "0")}.${String(cs).padStart(2, "0")}`;
    }

    component Round: Rectangle {
        property string icon
        signal clicked
        width: 44
        height: 44
        radius: 22
        color: Skin.s2
        Icon { anchors.centerIn: parent; text: parent.icon }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: parent.clicked() }
    }
}
