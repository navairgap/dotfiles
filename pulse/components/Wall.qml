import QtQuick
import qs

// wallpaper: the picture as a dot matrix (look 0), a grey photo tinted to the theme (1) or in color (2) — see shaders/wall.frag.
// two images: the one on screen and one in flight. when it lands — a wave from origin, then they trade places and the old one unloads.
// empty path — transparent: the grid and the orb live under the wallpaper. opaque — the picture covers it all, nothing under it needs drawing
Item {
    id: root

    property string path
    property int look: Skin.state.wallLook
    property real pitch: Skin.state.wallPitch
    property real bright: Skin.state.wallBright / 100
    property point origin: Qt.point(width / 2, height / 2)
    property bool animate: true // false — the swap is instant, no wave
    readonly property bool opaque: fx.hasA > 0 && !run.running

    property bool flip: false // who's on screen: false — ia, true — ib
    readonly property Image cur: flip ? ib : ia
    readonly property Image next: flip ? ia : ib

    function crop(img) {
        const ia = img.implicitWidth / Math.max(1, img.implicitHeight), sa = width / Math.max(1, height);
        return ia > sa ? Qt.size(sa / ia, 1) : Qt.size(1, ia / sa);
    }

    // ---- swapping: shown — the path on screen, coming — in flight ----
    property string shown: ""
    property string coming: ""
    property bool pending: false
    readonly property bool sized: width > 0 && height > 0 // no loading before a size: sourceSize 0 decodes the whole image

    onSizedChanged: change()
    onPathChanged: change()
    function change() {
        if (!sized) return;
        if (run.running) { // flipping faster than the wave — fast-forward the running swap
            run.stop();
            swap();
        }
        if (path === shown) {
            pending = false;
            next.source = "";
            return;
        }
        coming = path;
        pending = true;
        next.source = Skin.url(path);
        check();
    }
    function check() {
        if (!pending || next.status === Image.Loading) return;
        pending = false; // Error — it falls out to transparent, same as empty
        if (animate) run.restart();
        else swap();
    }
    function swap() {
        flip = !flip;
        shown = coming;
        fx.wave = 0;
        next.source = ""; // that's the old one now
    }

    NumberAnimation { id: run; target: fx; property: "wave"; from: 0; to: 1; duration: 1500; easing.type: Easing.InOutSine; onFinished: root.swap() }

    // texture sources — the effect's neighbours, not children: i hide the effect when there's no picture, and the scene never updates
    // the texture of an invisible Image. hence opacity 0, not visible: false. sourceSize is in logical pixels — qt multiplies by dpr itself
    Image { id: ia; opacity: 0; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(root.width, root.height); onStatusChanged: if (root.next === ia) root.check() }
    Image { id: ib; opacity: 0; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: ia.sourceSize; onStatusChanged: if (root.next === ib) root.check() }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: hasA > 0 || hasB > 0 || run.running // nothing to draw — no fullscreen pass either

        // ---- uniforms ----
        readonly property size size: Qt.size(width, height)
        readonly property point origin: root.origin
        readonly property var srcA: root.cur
        readonly property var srcB: root.next
        readonly property size cropA: root.crop(root.cur)
        readonly property size cropB: root.crop(root.next)
        readonly property real hasA: root.cur.status === Image.Ready ? 1 : 0
        readonly property real hasB: root.next.status === Image.Ready ? 1 : 0
        readonly property color lo: Skin.light ? Skin.fg : Skin.bg
        readonly property color hi: Skin.light ? Skin.bg : Skin.fg
        readonly property color bg: Skin.bg
        readonly property real pitch: root.pitch
        readonly property real bright: root.bright
        property real dots: root.look === 0 ? 1 : 0
        property real mono: root.look < 2 ? 1 : 0
        property real wave: 0
        Behavior on dots { NumberAnimation { duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
        Behavior on mono { NumberAnimation { duration: 700 } }

        fragmentShader: Qt.resolvedUrl("shaders/wall.frag.qsb")
    }
}
