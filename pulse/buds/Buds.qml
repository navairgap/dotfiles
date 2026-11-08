import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// nothing / cmf buds connected (sys.buds) — a card slides up from the bottom like the airpods popup: spring in, the device
// lights up as a dotted silhouette that resolves into the photo, charge rings wave in. tap to dismiss, it leaves on its own after 6s,
// hover keeps it. the photo is buds/<device-name>.png (official render from nothing.tech), no file — an icon instead
PanelWindow {
    id: root

    property string name
    readonly property string slug: name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") // cyrillic, emoji — an empty slug
    readonly property string art: slug ? Quickshell.shellPath("buds/" + slug + ".png") : ""

    // the show's timeline: t — the card, lit — the dotted silhouette, pop — the device settles into place, res — dots become photo
    property real t: 0
    property real lit: 0
    property real pop: 0
    property real res: 0
    property bool shown: false

    // buds already connected at shell start — stay quiet
    property bool armed: false
    Timer { running: true; interval: 3000; onTriggered: root.armed = true }
    Connections {
        target: Sys
        function onBudsChanged() { if (Sys.buds && root.armed) root.show(); }
    }

    function show() {
        name = Sys.buds.name;
        outA.stop();
        t = lit = pop = res = 0;
        shown = true;
        inA.restart();
    }
    function hide() {
        if (!shown) return;
        shown = false;
        inA.stop();
        outA.restart();
    }

    ParallelAnimation {
        id: inA
        NumberAnimation { target: root; property: "t"; to: 1; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1 }
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            ParallelAnimation {
                NumberAnimation { target: root; property: "lit"; to: 1; duration: 300 }
                NumberAnimation { target: root; property: "pop"; to: 1; duration: 750; easing.type: Easing.OutBack }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 800 }
            NumberAnimation { target: root; property: "res"; to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
    }
    NumberAnimation { id: outA; target: root; property: "t"; to: 0; duration: 380; easing.type: Easing.InCubic }
    Timer { interval: 6000; running: root.shown && !hov.hovered; onTriggered: root.hide() }

    // a gentle bob while visible
    property real bob: 0
    SequentialAnimation on bob {
        running: root.visible
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 1600; easing.type: Easing.InOutSine }
    }

    visible: t > 0
    anchors.bottom: true
    implicitWidth: Math.ceil(460 * Skin.s)
    implicitHeight: Math.ceil(520 * Skin.s)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: card }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pulse-buds"

    Stage {
        Rectangle {
            id: card
            x: 20
            // the window keeps 40 of headroom for the spring overshoot; at t = 0 the card sits fully below the screen edge
            y: 40 + (1 - root.t) * 480
            width: 420
            height: 456
            radius: Skin.corner(44)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
            opacity: Math.min(1, root.t * 1.5)

            HoverHandler { id: hov }
            TapHandler { onTapped: root.hide() }

            Lb { anchors.horizontalCenter: parent.horizontalCenter; y: 28; text: "connected"; px: 11 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 46
                text: root.name
                textFormat: Text.PlainText
                font { family: Skin.ui; pixelSize: 22; weight: Font.DemiBold }
                color: Skin.fg
            }

            Item {
                id: hero
                y: 84
                width: parent.width
                height: 230

                Orb { anchors.centerIn: parent; scale: 280 / 1100 }

                Item {
                    id: dev
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -6 * root.bob
                    width: 190
                    height: 220
                    scale: 0.7 + 0.3 * root.pop
                    rotation: -10 * (1 - root.pop)

                    // the silhouette: white led dots (black in light mode), fading out while the photo comes in
                    Item {
                        anchors.fill: parent
                        visible: photo.status === Image.Ready && opacity > 0
                        opacity: root.lit * (1 - root.res)
                        layer.enabled: visible
                        layer.effect: Dm { step: 6 }
                        Image {
                            anchors.fill: parent
                            source: photo.source
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            layer.enabled: true
                            layer.effect: MultiEffect { brightness: Skin.light ? -1 : 1 }
                        }
                    }
                    Image {
                        id: photo
                        anchors.fill: parent
                        source: root.art
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        opacity: root.res
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: photo.status === Image.Error
                        text: "\u{F02CB}"
                        font.pixelSize: 120
                        opacity: root.lit
                    }
                }
            }

            // charge: left, right, case (the case only when the buds are in it). nothing until ear answers
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 330
                spacing: 34
                Repeater {
                    model: ["l", "r", "case"].filter(k => Sys.ear?.[k] !== undefined)
                    Column {
                        id: bat
                        required property string modelData
                        readonly property real v: Sys.ear?.[modelData] ?? 0
                        // each ring gets its own wave: zero up to the charge, the number counts along
                        property real k: 0
                        NumberAnimation on k { from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
                        spacing: 8
                        Item {
                            width: 84
                            height: 84
                            Ring { anchors.fill: parent; n: 32; dot: 5; f: bat.v / 100 * bat.k }
                            Num { anchors.centerIn: parent; text: Math.round(bat.v * bat.k); font.pixelSize: 30 }
                        }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: bat.modelData; px: 11 }
                    }
                }
            }
        }
    }
}
