import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// clipboard: same family as the launcher panel, just wider — cliphist history as rows on the left, the selected
// entry in full on the right. search pill with a red caret, filters as chips (tab): all / text / links / images.
// type is a glyph in a circle, an image is a dot-matrix thumbnail, a color is itself. the selected row is a white
// pill. ⏎ puts it back on the clipboard; paste it yourself with ctrl+v
PanelWindow {
    id: root

    readonly property var types: ({
        code: "\u{F0169}", text: "\u{F09A8}", link: "\u{F0337}", image: "\u{F02E9}", color: "\u{F03D8}", file: "\u{F0214}"
    })
    readonly property var filters: ["all", "text", "links", "images"]
    // image previews live in XDG_RUNTIME_DIR, wiped on session exit
    readonly property string cache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pulse-clip-"

    property var entries: [] // { id, text, type }
    property var held: []
    property int filter: 0
    property int sel: 0
    property var cached: ({}) // image ids already sitting in the cache
    readonly property string query: input.text.toLowerCase()

    readonly property var view: entries.filter(e =>
        (filter === 0 || filter === 2 && e.type === "link" || filter === 3 && e.type === "image"
            || filter === 1 && e.type !== "link" && e.type !== "image")
        && e.text.toLowerCase().includes(query))
    readonly property var cur: view[sel] ?? null
    // the selected entry's full contents; until it lands, the preview makes do with what the list gave
    property string full: ""
    property string fullId: ""
    property string decId: ""
    readonly property string body: cur && fullId === cur.id ? full : cur?.text ?? ""

    function kind(t) {
        if (/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) \d+x\d+ \]\]$/.test(t)) return "image";
        if (t.startsWith("[[ binary data")) return "file";
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t)) return "color";
        if (/^https?:\/\/\S+$/.test(t)) return "link";
        if (/^(file:\/\/|~?\/)\S+$/.test(t)) return "file";
        // code is guessed off brackets and known commands; a miss just shows as text
        if (/[{};]|^(sudo|git|cd|qs|hyprctl|pacman|paru|yay|npm|cargo|systemctl|sh|bash|curl) /.test(t)) return "code";
        return "text";
    }
    // image: [size, format, width, height] out of "[[ binary data 340 KiB png 1920x1080 ]]"
    function img(e) { return e?.text.match(/binary data (.+) (\w+) (\d+)x(\d+) \]\]$/)?.slice(1) ?? ["", "", 0, 0]; }
    // css #RRGGBBAA → qt #AARRGGBB
    function rgb(s) { s = s.trim(); return s.length === 9 ? "#" + s.slice(7) + s.slice(1, 7) : s; }

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Skin.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Skin.glide } }

    function open() {
        list.running = true;
        input.text = "";
        filter = 0;
        sel = 0;
        shown = true;
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function move(d) { if (view.length) sel = Math.max(0, Math.min(sel + d, view.length - 1)); }

    function fire() {
        if (!cur) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", cur.id]);
        close();
    }
    // pinning only guards against deleting; cliphist max-items will push old stuff out either way
    function hold() {
        const id = cur?.id;
        if (!id) return;
        held = held.includes(id) ? held.filter(h => h !== id) : [...held, id];
        heldFile.setText(held.join("\n"));
    }
    function burn() {
        const it = cur;
        if (!it || held.includes(it.id)) return;
        del.exec(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", it.id]);
    }

    onQueryChanged: sel = 0
    onFilterChanged: sel = 0
    onViewChanged: sel = Math.max(0, Math.min(sel, view.length - 1))
    onSelChanged: rows.positionViewAtIndex(sel, ListView.Contain)
    onCurChanged: if (cur) decode.restart()
    onVisibleChanged: if (visible) input.forceActiveFocus()

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const t = l.slice(l.indexOf("\t") + 1);
                    return { id: l.slice(0, l.indexOf("\t")), text: t, type: root.kind(t) };
                });
            }
        }
    }
    Process { id: del; onExited: list.running = true }
    Process {
        id: dec
        stdout: StdioCollector { onStreamFinished: { root.full = text; root.fullId = root.decId; } }
    }
    // arrow keys held down — don't hammer cliphist per row. binary isn't decoded here: images get cached by the
    // row, the rest is junk
    Timer {
        id: decode
        interval: 80
        onTriggered: {
            if (!root.cur || root.cur.text.startsWith("[[ binary data")) return;
            root.decId = root.cur.id;
            dec.exec(["sh", "-c", 'cliphist decode "$1" | head -c 4000', "sh", root.cur.id]);
        }
    }
    FileView {
        id: heldFile
        path: Quickshell.statePath("clip-held")
        printErrors: false
        onLoaded: root.held = text().split("\n").filter(l => l)
    }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "pulse-clip"

    Rectangle {
        anchors.fill: parent
        color: Skin.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: 140 + 24 * (1 - root.t)
            width: 1120
            height: Math.min(stage.height - 280, 760)
            opacity: root.t
            radius: Skin.corner(44)
            color: Skin.s1
            border { width: 1; color: Skin.s2 }
            MouseArea { anchors.fill: parent }

            // search: pill, red caret, filter chips — same as the launcher
            Rectangle {
                id: search
                x: 34
                y: 30
                width: parent.width - 68
                height: 66
                radius: Skin.corner(33)
                color: Skin.s2

                Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Skin.grey; font.pixelSize: 22 }
                TextInput {
                    id: input
                    focus: true
                    anchors { left: lens.right; leftMargin: 16; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font { family: Skin.ui; pixelSize: 22 }
                    color: Skin.fg
                    selectionColor: Skin.s3
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Skin.accent
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text {
                        visible: !input.text
                        x: 6
                        text: "Search clipboard"
                        font: input.font
                        color: Skin.mute
                    }
                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.fire();
                        else if (e.key === Qt.Key_Tab) root.filter = (root.filter + 1) % 4;
                        else if (e.key === Qt.Key_Backtab) root.filter = (root.filter + 3) % 4;
                        else if (e.key === Qt.Key_Down || ctrl && e.key === Qt.Key_J) root.move(1);
                        else if (e.key === Qt.Key_Up || ctrl && e.key === Qt.Key_K) root.move(-1);
                        else if (ctrl && e.key === Qt.Key_P) root.hold();
                        else if (e.key === Qt.Key_Delete) root.burn();
                        else return;
                        e.accepted = true;
                    }
                }
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: root.filters
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: chip.width + 32
                            height: chip.height + 20
                            radius: height / 2
                            color: root.filter === index ? Skin.fg : "transparent"
                            Lb { id: chip; anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.filter === parent.index ? Skin.ink : Skin.grey }
                            TapHandler { onTapped: { root.filter = parent.index; input.forceActiveFocus(); } }
                        }
                    }
                }
            }

            Row {
                id: head
                x: 42
                y: search.y + search.height + 30
                spacing: 14
                Num { anchors.baseline: hlab.baseline; text: root.view.length; font.pixelSize: 34 }
                Lb { id: hlab; text: root.view.length === 1 ? "entry" : "entries" }
            }

            ListView {
                id: rows
                anchors { left: parent.left; leftMargin: 34; top: head.bottom; topMargin: 18; bottom: parent.bottom; bottomMargin: 34 }
                width: 500
                clip: true
                spacing: 4
                model: root.view
                boundsBehavior: Flickable.StopAtBounds
                delegate: Entry {}
            }

            // the selected entry in full
            Rectangle {
                id: card
                anchors { left: rows.right; leftMargin: 24; right: parent.right; rightMargin: 34; top: head.top; bottom: parent.bottom; bottomMargin: 34 }
                radius: Skin.corner(40)
                color: Skin.s2

                Lb { id: kindLb; x: 30; y: 30; text: root.cur ? `${root.cur.type} · ${root.sel + 1} of ${root.view.length}` : "" }
                Row {
                    anchors { right: parent.right; rightMargin: 30; verticalCenter: kindLb.verticalCenter }
                    visible: !!root.cur && root.held.includes(root.cur.id)
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F0403}"; font.pixelSize: 15 }
                    Lb { text: "pinned"; color: Skin.fg }
                }
                Loader {
                    anchors { left: parent.left; right: parent.right; top: kindLb.bottom; bottom: parent.bottom; margins: 30; topMargin: 26 }
                    clip: true
                    sourceComponent: root.cur ? ({ text: textPv, code: codePv, link: linkPv, color: colorPv, image: imagePv, file: filePv })[root.cur.type] : emptyPv
                }
            }

            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 28 }
                spacing: 34
                Repeater {
                    model: ["↑↓ select", "↵ copy", "tab filter", "^p pin", "del delete", "esc close"]
                    Lb { required property string modelData; text: modelData }
                }
            }
        }
    }

    // a history row: 48 circle (glyph / dot-matrix thumbnail / the color itself), text on one line, doto number
    // on the right. selected — white pill, black text
    component Entry: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property string type: modelData.type
        readonly property var m: type === "image" ? root.img(modelData) : null
        readonly property bool on: root.sel === index
        width: rows.width
        height: 64
        radius: Skin.corner(32)
        color: on ? Skin.fg : "transparent"

        Rectangle {
            id: dot
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            radius: 24
            color: row.type === "color" ? root.rgb(row.modelData.text) : row.on ? Skin.ink : Skin.s2
            border { width: row.type === "color" ? 1 : 0; color: Skin.s3 }
            Icon {
                anchors.centerIn: parent
                visible: row.type !== "image" && row.type !== "color"
                text: root.types[row.type]
                font.pixelSize: 22
            }
            Art {
                anchors.fill: parent
                visible: row.type === "image"
                step: 3
                url: root.cached[row.modelData.id] ? "file://" + root.cache + row.modelData.id : ""
            }
        }
        // images go to the cache the first time their row shows up: the whole history at once would be hundreds of
        // MB in tmpfs. written to a temp file first so the preview never grabs a half-written one
        Process {
            running: row.type === "image" && !root.cached[row.modelData.id]
            command: ["sh", "-c", 'f="$1$2"; [ -s "$f" ] || { cliphist decode "$2" > "$f.$$" && mv "$f.$$" "$f"; }', "sh", root.cache, row.modelData.id]
            onExited: code => { if (!code) root.cached = Object.assign({}, root.cached, { [row.modelData.id]: true }); }
        }
        Column {
            anchors { left: dot.right; leftMargin: 14; right: tail.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 3
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: row.m ? `${row.m[2]}×${row.m[3]}` : row.modelData.text.replace(/\s+/g, " ").trim()
                font { family: Skin.ui; pixelSize: 15; weight: Font.Medium }
                color: row.on ? Skin.ink : Skin.fg
            }
            Lb {
                text: row.m ? `image · ${row.m[1]} · ${row.m[0]}` : row.type
                px: 10
                color: row.on ? Skin.ink : Skin.grey
                opacity: row.on ? 0.6 : 1
            }
        }
        Row {
            id: tail
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 12
            Icon { anchors.verticalCenter: parent.verticalCenter; visible: root.held.includes(row.modelData.id); text: "\u{F0403}"; font.pixelSize: 16; color: row.on ? Skin.ink : Skin.fg }
            Num { anchors.verticalCenter: parent.verticalCenter; text: String(row.index + 1).padStart(2, "0"); font.pixelSize: 26; color: row.on ? Skin.ink : Skin.mute }
        }
        // click to select, click the selected to copy
        TapHandler {
            onTapped: {
                if (row.on) root.fire();
                else root.sel = row.index;
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // ---- previews per type: the Loader stretches them across the card. clipboard content renders as PlainText
    // only — html sneaks in there ----
    Component {
        id: textPv
        Text {
            text: root.body.trim()
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            font { family: Skin.ui; pixelSize: 26; weight: Font.Light }
            lineHeight: 1.2
            color: Skin.fg
        }
    }
    Component {
        id: codePv
        // long lines just get cut off by the card edge
        Text {
            text: root.body.replace(/\s+$/, "")
            textFormat: Text.PlainText
            font { family: Skin.mono; pixelSize: 14 }
            lineHeight: 1.6
            color: Skin.fg
        }
    }
    Component {
        id: linkPv
        Column {
            spacing: 14
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.body.match(/^\w+:\/\/([^\/?#]+)/)?.[1] ?? root.body
                font { family: Skin.ui; pixelSize: 44; weight: Font.Medium; letterSpacing: -0.88 }
                color: Skin.fg
            }
            Mono { text: root.body.trim() }
        }
    }
    Component {
        id: colorPv
        Column {
            readonly property color c: root.rgb(root.body)
            spacing: 28
            Rectangle { width: 200; height: 200; radius: 100; color: parent.c; border { width: 1; color: Skin.s3 } }
            Num { textFormat: Text.PlainText; text: root.body.trim().toUpperCase(); font.pixelSize: 64 }
            Lb { text: `rgb ${[parent.c.r, parent.c.g, parent.c.b].map(v => Math.round(v * 255)).join(" ")}` }
        }
    }
    Component {
        id: imagePv
        // the image as dots, like the covers: monochrome, step 3
        Column {
            id: ipv
            readonly property var m: root.img(root.cur)
            spacing: 22
            Image {
                width: parent.width
                height: parent.height - dims.height - parent.spacing
                source: root.cached[root.cur?.id] ? "file://" + root.cache + root.cur.id : ""
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                asynchronous: true
                layer.enabled: true
                layer.effect: Dm { step: 3 }
            }
            Row {
                id: dims
                spacing: 14
                Num { anchors.baseline: dlab.baseline; text: `${ipv.m[2]}×${ipv.m[3]}`; font.pixelSize: 34 }
                Lb { id: dlab; text: `${ipv.m[1]} · ${ipv.m[0]}` }
            }
        }
    }
    Component {
        id: filePv
        Column {
            spacing: 20
            Rectangle {
                width: 96
                height: 96
                radius: 48
                color: Skin.s3
                Icon { anchors.centerIn: parent; text: root.types.file; font.pixelSize: 40 }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.body.trim().replace(/\/$/, "").split("/").pop()
                font { family: Skin.ui; pixelSize: 34; weight: Font.Medium; letterSpacing: -0.68 }
                color: Skin.fg
            }
            Mono { text: root.body.trim() }
        }
    }
    Component {
        id: emptyPv
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 18
                Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "\u{F014C}"; font.pixelSize: 48; color: Skin.mute }
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: root.entries.length ? "no matches" : "clipboard is empty" }
            }
        }
    }

    // the full path / url small under the big name
    component Mono: Text {
        width: parent?.width ?? 0
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 8
        elide: Text.ElideRight
        font { family: Skin.mono; pixelSize: 14 }
        lineHeight: 1.5
        color: Skin.grey
    }
}
