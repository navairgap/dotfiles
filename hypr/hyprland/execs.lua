local vars = require("variables")
local fn   = require("hyprland.functions")

hl.on("hyprland.start", function()
    -- shell: whichever one rice has selected
    hl.exec_cmd(vars.rice .. " start")

    -- nested session: the system daemons are already running on the host
    if vars.nested then return end

    -- keyring and auth agent
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- empty trash older than 30 days
    hl.exec_cmd("trash-empty 30")

    -- cursor theme and size everywhere they can be set
    hl.exec_cmd("hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. vars.cursorTheme)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. vars.cursorSize)

    -- location agent
    hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")

    -- forward bluetooth media commands into mpris
    hl.exec_cmd("mpris-proxy")

    -- hypridle starts the shell (Rules.idle): its timings come from the house rules → ~/.config/pulse/hypridle.conf
end)

-- bitwarden and pip get sized to fit, on open and on title change
hl.on("window.title", function(win)
    local centered = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip = fn.move_actions(win) or {}

    fn.resizer(win, "Bitwarden", 20, 54, centered, true)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip, false)
end)

hl.on("window.open", function(win)
    local centered = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip = fn.move_actions(win) or {}

    fn.resizer(win, "Bitwarden", 20, 54, centered, true)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip, false)
end)
