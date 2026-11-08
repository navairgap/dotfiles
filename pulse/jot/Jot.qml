import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// jot: sticky notes, a stack of cards you type straight into. opened from the desktop menu (right-click the
// wallpaper) — no bind of its own, it's a scratchpad, not a destination. one file, state/jot.json; every edit
// lands the moment you make it, there is no save button to forget
PanelWindow {
    id: root

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
    property var notes: [] // [{ t, d }] — text and when it was written

    FileView {
        id: file
        path: Quickshell.statePath("jot.json")
        printErrors: false
        onLoaded: {
            try { root.notes = JSON.parse(text()).filter(n => n && typeof n.t === "string"); } catch (e) { root.notes = []; }
        }
    }
    function save() { file.setText(JSON.stringify(root.notes)); }
    function add() {
        notes = notes.concat([{ t: "", d: new Date().toISOString() }]);
        // focus lands after the delegate exists
        Qt.callLater(() => {
            const items = [...cards.children];
            const last = items[items.length - 1];
            if (last?.area) last.area.forceActiveFocus();
        });
    }
    function drop(i) { notes = notes.filter((_, k) => k !== i); }

    function open() { shown = true; }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }

    onVisibleChanged: if (visible) notes = notes // touch: the empty-state label re-reads

    readonly property date now: new Date()
    Timer { running: root.shown; interval: 30000; repeat: true; onTriggered: root.now = new Date() }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-jot"

    Rectangle {
        anchors.fill: parent
        color: Skin.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 + 24 * (1 - root.t)
            width: 560
            height: Math.min(stage.height - 220, 30 + 44 + 16 + list.contentHeight + 62)
            opacity: root.t
            radius: Skin.corner(44)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
            MouseArea { anchors.fill: parent }

            Row {
                x: 34
                y: 28
                width: parent.width - 68
                spacing: 14
                Num { text: "jot"; font.pixelSize: 30 }
                Lb { anchors.verticalCenter: parent.verticalCenter; text: root.notes.length + (root.notes.length === 1 ? " note" : " notes"); px: 11 }
                Lb {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: "esc out"
                    px: 10
                    opacity: 0.7
                }
            }

            Flickable {
                id: list
                x: 34
                y: 86
                width: parent.width - 68
                height: parent.height - 86 - 62
                clip: true
                contentHeight: cards.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: cards
                    width: parent.width
                    spacing: 14

                    Repeater {
                        model: root.notes

                        Rectangle {
                            id: note
                            required property int index
                            required property var modelData
                            width: cards.width
                            height: Math.max(96, area.topPadding + area.bottomPadding + area.contentHeight + 56)
                            radius: Skin.corner(28)
                            color: Skin.s2
                            border { width: 1; color: Skin.s3 }

                            TextArea {
                                id: area
                                x: 20
                                y: 14
                                width: parent.width - 40
                                background: null
                                wrapMode: TextArea.Wrap
                                text: note.modelData.t
                                onTextChanged: if (text !== root.notes[note.index]?.t) {
                                    const next = root.notes.slice();
                                    next[note.index] = { t: text, d: root.notes[note.index].d };
                                    root.notes = next;
                                    root.save();
                                }
                                color: Skin.fg
                                selectionColor: Skin.s3
                                font { family: Skin.ui; pixelSize: 16 }
                                placeholderText: "type…"
                                placeholderTextColor: Skin.mute
                                cursorDelegate: Rectangle {
                                    width: 2
                                    color: Skin.accent
                                    Timer { running: area.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                                }
                                Keys.onPressed: e => { if (e.key === Qt.Key_Escape) root.close(); }
                            }
                            Row {
                                x: 20
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                spacing: 8
                                Lb {
                                    text: Qt.locale("en_US").toString(new Date(note.modelData.d), "d MMM · h:mm")
                                    px: 10
                                    opacity: 0.7
                                }
                            }
                            // delete on hover: an x in the corner, red while hovered
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 10 }
                                width: 26
                                height: 26
                                radius: 13
                                color: delHov.hovered ? Skin.red : "transparent"
                                Behavior on color { ColorAnimation { duration: Skin.t } }
                                Lb { anchors.centerIn: parent; text: "×"; color: delHov.hovered ? Skin.ink : Skin.mute; px: 13 }
                                HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.drop(note.index) }
                            }
                        }
                    }
                    Lb { visible: !root.notes.length; x: 6; text: "empty — the + below starts one"; px: 12 }
                }
            }

            // new note: a red dot at the bottom — the one live thing on the card
            Rectangle {
                x: parent.width - 74
                y: parent.height - 62
                width: 44
                height: 44
                radius: 22
                color: Skin.accent
                Icon { anchors.centerIn: parent; text: "+"; color: Skin.on(Skin.accent); font.pixelSize: 24 }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.add() }
            }
        }
    }
}
