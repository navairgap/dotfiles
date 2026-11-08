import QtQuick
import qs
import qs.components

// toggle: a pill. off — grey dot on the left with the label beside it; on — the white fills the whole length, the dot ends up at
// the right edge, the label slides left and goes dark. click, space, ↵ — flip; ← off, → on
Rectangle {
    id: root

    property bool on
    property string text
    signal flip

    width: Math.max(170, lab.implicitWidth + 96)
    height: 64
    radius: Skin.corner(32)
    color: Skin.s2
    border { width: activeFocus ? 1 : 0; color: Skin.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) flip();
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) { if (on !== (e.key === Qt.Key_Right)) flip(); }
        else return;
        e.accepted = true;
    }

    Rectangle {
        x: 6
        y: 6
        width: root.on ? root.width - 12 : height
        height: root.height - 12
        radius: Skin.corner(height / 2)
        color: root.on ? Skin.fg : Skin.mute
        Behavior on width { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
        Behavior on color { ColorAnimation { duration: Skin.t } }
        Rectangle {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            width: 12
            height: 12
            radius: 6
            color: root.on ? Skin.ink : Skin.s2
        }
    }
    Lb {
        id: lab
        x: root.on ? 30 : 76 // on — the dot owns the right, the label steps aside
        Behavior on x { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.on ? Skin.ink : root.activeFocus ? Skin.fg : Skin.grey
        Behavior on color { ColorAnimation { duration: Skin.t } }
    }
    TapHandler { onTapped: root.flip() }
}
