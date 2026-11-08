-- monitor: hypr decides the scale (the shell enforces its own later, Rules.monitor)
hl.monitor({ output = "", mode = "highres", position = "auto", scale = "auto" })

-- xwayland is scaled by hypr: blurry on hidpi, but the size comes out right at any scale. crisp on an integer scale — in user.lua:
--   hl.config({ xwayland = { force_zero_scaling = true } }); hl.env("GDK_SCALE", "2")

-- configs
require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")

-- my binds and tweaks layered over the rice: hypr/user.lua (gitignored, repo updates never touch it)
local user = io.open(os.getenv("HOME") .. "/.config/hypr/user.lua")
if user then user:close(); require("user") end
