import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// jot: sticky notes, a stack of cards you type straight into. opened from the desktop menu (right-click the
// wallpaper) — no bind of its own, it's a scratchpad, not a destination. one file, state/jot.json.
// the text lives in the TextArea while you type — the model only gets it on focus loss or closing: writing
// back on every keystroke would rebuild every card under the cursor and eat the caret. no save button to forget
PanelWindow {
    id: root

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }
    property var notes: [] // [{ t, d }] — text and when it was written
    property int dirty: -1 // the card being typed: its text is in the widget, not the model yet
    property var dirtyArea: null

    FileView {
        id: file
        path: Quickshell.statePath("jot.json")
        printErrors: false
        onLoaded: {
            try { root.notes = JSON.parse(text()).filter(n => n && typeof n.t === "string"); } catch (e) { root.notes = []; }
        }
    }
    function save() { file.setText(JSON.stringify(root.notes)); }
    // the editor hands its text over; nothing happens when nothing changed
    function commit() {
        if (dirty < 0 || !dirtyArea) { dirty = -1; dirtyArea = null; return; }
        const text = dirtyArea.text;
        const cur = notes[dirty];
        if (cur && cur.t !== text) {
            const next = notes.slice();
            next[dirty] = { t: text, d: cur.d };
            notes = next;
            save();
        }
        dirty = -1;
        dirtyArea = null;
    }
    function add() {
        commit(); // flush whatever was being typed first, or it lands in the wrong card after the rebuild
        notes = notes.concat([{ t: "", d: new Date().toISOString() }]);
        // focus lands after the delegate exists — field is the editor, aliased off the card
        Qt.callLater(() => {
            const items = cards.children;
            const last = items[items.length - 1];
            if (last?.field) last.field.forceActiveFocus();
        });
    }
    function drop(i) {
        commit();
        notes = notes.filter((_, k) => k !== i);
        save();
    }

    function open() { shown = true; }
    function close() { commit(); shown = false; }
    function toggle() { shown ? close() : open(); }
    onVisibleChanged: if (!visible) commit()

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
                            property alias field: area
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
                                onTextChanged: {
                                    // mark the card dirty; the model catches up on blur or close
                                    root.dirty = note.index;
                                    root.dirtyArea = area;
                                }
                                onEditingFinished: root.commit()
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
