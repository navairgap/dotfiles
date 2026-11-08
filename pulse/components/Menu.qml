import QtQuick
import qs

// a nothing menu: black card, rows in caps, hover white, "-" is a line. it fills whatever stage it sits in —
// the card lands at openAt(x, y, items), clamped to the screen, and a click anywhere outside folds it.
// items: { label, run } — run closes the menu itself if it doesn't
Item {
    id: root

    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
    property bool open: false
    property var items: []
    property point at: Qt.point(0, 0)

    function openAt(x, y, list) {
        root.items = list ?? [];
        root.at = Qt.point(x, y);
        root.open = true;
    }
    function close() { root.open = false; }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: card
        x: Math.max(12, Math.min(root.at.x, parent.width - width - 12))
        y: Math.max(12, Math.min(root.at.y, parent.height - height - 12))
        width: 264
        height: rows.height + 14
        radius: Skin.corner(30)
        color: Skin.s1
        border { width: 1; color: Skin.s2 }
        opacity: root.open ? 1 : 0
        transform: Translate { y: -10 * (1 - root.opacity) }

        Column {
            id: rows
            x: 8
            y: 8
            width: parent.width - 16

            Repeater {
                model: root.items

                Item {
                    id: row
                    required property var modelData
                    width: rows.width
                    height: modelData === "-" ? 9 : 44

                    Rectangle {
                        visible: row.modelData === "-"
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Skin.s2
                    }
                    Rectangle {
                        visible: row.modelData !== "-"
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Skin.corner(20)
                        color: hover.hovered ? Skin.fg : "transparent"
                        Behavior on color { ColorAnimation { duration: Skin.t } }

                        Lb {
                            x: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label ?? ""
                            color: hover.hovered ? Skin.ink : Skin.grey
                        }
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { const r = row.modelData.run; root.close(); if (r) r(); } }
                    }
                }
            }
        }
    }
}
