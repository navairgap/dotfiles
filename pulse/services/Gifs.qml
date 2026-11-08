pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs

// gifs for the home cat tile (home/Gif) and its picker in settings → home: every *.gif in Skin.state.gifDir
// (empty — ~/Pictures/Gifs); none there — the built-in cat. the pick is Skin.state.gif, a path; empty — the first one
Singleton {
    id: root

    readonly property string dir: Skin.state.gifDir || Quickshell.env("HOME") + "/Pictures/Gifs"
    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        nameFilters: ["*.gif"]
        caseSensitive: false
        showDirs: false
    }
    readonly property bool ready: folder.status === FolderListModel.Ready // the folder loads async: until then the list is just the cat
    readonly property var list: {
        const a = [];
        for (let i = 0; i < folder.count; i++) a.push(folder.get(i, "filePath"));
        return a.length ? a : [""];
    }
    readonly property int sel: Math.max(0, list.indexOf(Skin.state.gif))
    readonly property string cur: list[sel]

    function pick(p) { Skin.state.gif = p; }
    function step(d) { if (list.length > 1) pick(list[(sel + d + list.length) % list.length]); }
    function name(p) { return p ? p.slice(p.lastIndexOf("/") + 1).replace(/\.gif$/i, "") : "cat"; }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : Qt.resolvedUrl("../home/cat.gif"); }
    // the crop for wall.frag that keeps a gif of any shape whole inside the square: past the edge the texture stretches the border pixels
    function fit(img) {
        const w = img.implicitWidth, h = img.implicitHeight;
        return w && h ? (w > h ? Qt.size(1, w / h) : Qt.size(h / w, 1)) : Qt.size(1, 1);
    }
}
