import QtQuick
import qs
import qs.components

// a swatch (Skin.styles): a circle of fill with the accent (dot) inside, the name under it; amount — a ring of dots round it, the
// colour share of a variant, like a Pulse meter. focus — a white ring, the one in place — a dot in the centre. click, ↵, space set
// it, ←→ — the neighbour. hover takes focus, like in Power: one cursor, ↵ sets what the mock-up shows. peek — focused: STYLE paints its palette on the mock-up
Column {
    id: root

    property var item: ({ name: "" })
    property real size: 56
    readonly property bool peek: activeFocus

    width: 96
    spacing: 8
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) item.run();
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) nextItemInFocusChain(e.key === Qt.Key_Right)?.forceActiveFocus();
        else return;
        e.accepted = true;
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.size + 28
        height: width
        Ring {
            visible: root.item.amount !== undefined
            anchors.fill: parent
            n: visible ? 24 : 0 // the ring is only for variants — no reason for the rest to hold 24 dots
            dot: 3
            f: root.item.amount ?? 0
            on: root.item.dot ?? Skin.fg
        }
        Rectangle {
            anchors.centerIn: parent
            width: root.size + 14
            height: width
            radius: width / 2
            color: "transparent"
            border { width: 2; color: root.activeFocus ? Skin.fg : "transparent" }
        }
        Rectangle {
            id: disc
            anchors.centerIn: parent
            width: root.size
            height: width
            radius: width / 2
            color: root.item.fill ?? Skin.s2
            border { width: 1; color: Skin.s3 } // a black swatch on black
            Behavior on color { ColorAnimation { duration: Skin.t } }
            Rectangle {
                id: inner
                visible: !!root.item.dot
                anchors.centerIn: parent
                width: Math.round(root.size * 0.46)
                height: width
                radius: width / 2
                color: root.item.dot ?? "transparent"
                Behavior on color { ColorAnimation { duration: Skin.t } }
            }
            Rectangle { visible: !!root.item.now; anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: Skin.on(inner.visible ? inner.color : disc.color) }
        }
        TapHandler { onTapped: { root.forceActiveFocus(); root.item.run(); } }
        HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.forceActiveFocus() }
    }
    Lb {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        px: 10
        text: root.item.name
        color: root.activeFocus || root.item.now ? Skin.fg : Skin.grey
    }
}
