import QtQuick

// wheel by notches: notch(±1) per 120 of angle. a high-res wheel sends 15 per click — so i accumulate, else it's 8 steps per notch.
// MouseArea, not WheelHandler: on the bar's pill the handler never saw the wheel (it checks the point against the window geometry too), MouseArea does.
// no touchpad (scrollGestureEnabled) — a swipe must not scroll; clicks and hover pass through
MouseArea {
    signal notch(int d) // +1 — wheel away from me
    property real acc: 0
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: false
    onWheel: e => {
        const dy = (e.inverted ? -1 : 1) * (e.angleDelta.y || e.angleDelta.x); // natural scroll — wheel away is still +1
        if (acc * dy < 0) acc = 0; // direction flipped mid-notch — the remainder doesn't count
        acc += dy;
        while (Math.abs(acc) >= 120) {
            notch(Math.sign(acc));
            acc -= Math.sign(acc) * 120;
        }
    }
}
