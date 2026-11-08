import QtQuick
import qs
import qs.components
import qs.services

// the cat tile's gif — Gifs.cur (services/Gifs: the gif folder, picked here or in settings → home). drawn as a
// grey dot matrix through the wallpaper shader, as before. click — next, wheel — browse; the new one comes in as
// a shader wave from the click (from the center when it was picked in settings)
Item {
    id: root

    property bool playing: true
    property color bg // the tile's color: transparent bits of the gif blend into it

    function step(d, at) {
        if (at) fx.origin = at;
        Gifs.step(d);
    }

    // like components/Wall: one on screen, one in flight; when the wave lands they trade places and the old one unloads
    property bool flip: false
    readonly property AnimatedImage cur: flip ? b : a
    readonly property AnimatedImage next: flip ? a : b
    property string shown: "-" // nothing yet
    property string coming

    readonly property string want: Gifs.cur
    onWantChanged: change()
    readonly property bool ready: Gifs.ready
    onReadyChanged: change()
    Component.onCompleted: change()
    function change() {
        if (!ready) return;
        if (run.running) {
            run.stop();
            swap();
        }
        if (want === shown) return;
        coming = want;
        next.source = Gifs.url(want); // local files load synchronously
        if (shown === "-") swap();
        else run.restart();
    }
    function swap() {
        flip = !flip;
        shown = coming;
        fx.wave = 0;
        next.source = "";
    }
    NumberAnimation {
        id: run
        target: fx
        property: "wave"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.InOutSine
        onFinished: {
            root.swap();
            fx.origin = Qt.point(fx.width / 2, fx.height / 2);
        }
    }

    // texture sources — the effect's opacity-0 neighbours, see Wall
    AnimatedImage { id: a; anchors.fill: fx; opacity: 0; playing: root.playing && root.cur === a || run.running }
    AnimatedImage { id: b; anchors.fill: fx; opacity: 0; playing: root.playing && root.cur === b || run.running }

    ShaderEffect {
        id: fx
        anchors { fill: parent; margins: 12 }
        readonly property size size: Qt.size(width, height)
        property point origin: Qt.point(width / 2, height / 2)
        readonly property size cropA: Gifs.fit(root.cur)
        readonly property size cropB: Gifs.fit(root.next)
        readonly property color lo: Skin.light ? Skin.fg : Skin.bg
        readonly property color hi: Skin.light ? Skin.bg : Skin.fg
        readonly property color bg: root.bg
        readonly property real pitch: 6
        readonly property real dots: 1
        readonly property real mono: 1
        readonly property real bright: 1
        property real wave: 0
        readonly property real hasA: root.cur.status === Image.Ready ? 1 : 0
        readonly property real hasB: root.next.status === Image.Ready ? 1 : 0
        readonly property var srcA: root.cur
        readonly property var srcB: root.next
        fragmentShader: Qt.resolvedUrl("../components/shaders/wall.frag.qsb")
    }

    TapHandler { onTapped: p => root.step(1, root.mapToItem(fx, p.position)) }
    Notch { onNotch: d => root.step(-d) }
    HoverHandler { cursorShape: Gifs.list.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor }
}
