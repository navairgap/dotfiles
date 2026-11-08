import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "lock"

// the lock is a separate process: qs -p …/pulse/lock.qml (`rice lock` calls it). unlocked — we quit.
// the shell dying leaves the lock alive; the lock dying — hyprland keeps the screen off, SUPER+ALT+L brings it back up
ShellRoot {
    id: shell
    // hot-reload recreates WlSessionLock: the old one dies and the process lingers with no screen
    settings.watchFiles: false

    QtObject {
        id: gate
        property string buffer: ""
        property bool fail: false
        property bool leaving: false // password accepted: the surface plays out its exit, then unlockT drops the lock
        readonly property bool busy: pam.active
        function submit() {
            if (!buffer || pam.active || leaving) return;
            pam.start();
        }
    }

    PamContext {
        id: pam
        config: "lock"
        configDirectory: Quickshell.shellPath("pam")
        onResponseRequiredChanged: if (responseRequired) respond(gate.buffer)
        onCompleted: res => {
            gate.buffer = "";
            if (res === PamResult.Success) {
                gate.leaving = true;
                unlockT.start();
            } else gate.fail = true;
        }
    }
    Timer { id: unlockT; interval: 470; onTriggered: lock.locked = false }

    property string layout: "en"
    function short(name) { return name.slice(0, 2).toLowerCase(); }
    Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap'"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) shell.layout = shell.short(text.trim()) }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") shell.layout = shell.short(e.data.split(",").pop()); }
    }

    WlSessionLock {
        id: lock
        locked: true
        // note: lockedChanged never arrives after locked = false (quickshell 0.3.2), but secure does drop — quit on it
        onSecureChanged: if (!secure) Qt.quit()

        LockSurface { auth: gate; layout: shell.layout }
    }
}
