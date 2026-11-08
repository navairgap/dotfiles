local vars = require("variables")
local fn   = require("hyprland.functions")

hl.on("hyprland.start", function()
    -- hand the session env to the user manager, then bring up the session target: the units in systemd/user/
    -- (shell, hypridle, hyprsunset, clipboard) start with it, and a dead one restarts itself
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start graphical-session.target")

    -- shell: whichever one rice has selected (rice routes through the systemd unit when there is one)
    hl.exec_cmd(vars.rice .. " start")

    -- nested session: the system daemons are already running on the host
    if vars.nested then return end

    -- keyring and auth agent
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- clipboard history: the pulse-clipboard unit (started with the session target); watchers respawn if they die

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

    -- hypridle and hyprsunset are units too: the shell writes their config (Rules.idle/night) and restarts them
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
