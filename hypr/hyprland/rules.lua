local vars = require("variables")

-- window rules

hl.window_rule({ match = { fullscreen = false }, opacity = vars.windowOpacity .. " override" })

-- apps (kitty) ask for maximize on open themselves; ignore it, tiling makes the call
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

hl.window_rule({ match = { float = true, xwayland = false }, center = true }) -- center floats; not xwayland, that catches popups

-- floating apps
hl.window_rule({
    match = {
        class =
        "guifetch|yad|zenity|wev|org.gnome.FileRoller|file-roller|blueman-manager|com.github.GradienceTeam.Gradience|feh|imv|system-config-printer|org.quickshell",
    },
    tag   = "+float",
})
hl.window_rule({
    match = {
        title =
        "(Select|Open)( a)? (File|Folder)(s)?|File (Operation|Upload)( Progress)?|.* Properties|Export Image as PNG|GIMP Crash Debug|Save As|Library",
    },
    tag   = "+float",
})
hl.window_rule({ match = { class = "steam", title = "Friends List" }, tag = "+float" })
hl.window_rule({ match = { class = "com-atlauncher-App", title = "ATLauncher Console" }, tag = "+float" })
hl.window_rule({ match = { class = "PandoraLauncher", title = "Minecraft Game Output" }, tag = "+float" })

hl.window_rule({ match = { tag = "float" }, float = true })

-- opaque apps (terminal, image viewers, creative software, games): they do their own transparency
hl.window_rule({
    match = {
        class =
        "kitty|equibop|org.quickshell|com.t3tools.T3Code|imv|swappy|krita|gimp|inkscape|darktable|resolve|kdenlive|shotcut|blender|godot|(steam_app_(default|[0-9]+))|gamescope",
    },
    tag   = "+opaque_app",
})

hl.window_rule({ match = { tag = "opaque_app" }, opaque = true })

-- floats with a set size, centered
hl.window_rule({ match = { class = "org.quickshell", title = "Rice" }, float = true, center = true }) -- the shell switcher
hl.window_rule({ match = { class = "kitty", title = "nmtui" }, tag = "+float_60_70" })
hl.window_rule({ match = { class = "org.pulseaudio.pavucontrol|yad-icon-browser" }, tag = "+float_60_70" })
hl.window_rule({ match = { class = "org.gnome.Settings" }, tag = "+float_70_80" })
hl.window_rule({ match = { class = "nwg-look" }, tag = "+float_50_60" })

hl.window_rule({
    match  = { tag = "float_60_70" },
    float  = true,
    size   = "(monitor_w*0.6) (monitor_h*0.7)",
    center = true,
})
hl.window_rule({
    match  = { tag = "float_70_80" },
    float  = true,
    size   = "(monitor_w*0.7) (monitor_h*0.8)",
    center = true,
})
hl.window_rule({
    match  = { tag = "float_50_60" },
    float  = true,
    size   = "(monitor_w*0.5) (monitor_h*0.6)",
    center = true,
})

-- games (steam, lutris/wine, gamescope)
hl.window_rule({
    match        = { class = "(steam_app_(default|[0-9]+))|gamescope" },
    immediate    = true,
    idle_inhibit = "always",
})

-- picture in picture: final size and position come from the title listener, this floats, pins and keeps the ratio
hl.window_rule({
    match             = { title = "Picture(-| )in(-| )[Pp]icture" },
    move              = "(monitor_w*0.98-window_w) (monitor_h*0.97-window_h)",
    pin               = true,
    float             = true,
    keep_aspect_ratio = true,
})

-- ueberzugpp
hl.window_rule({ match = { class = "^(ueberzugpp_.*)$" }, float = true, no_initial_focus = true })

-- autodesk fusion 360
hl.window_rule({ match = { class = "fusion360.exe", title = "Fusion360|(Marking Menu)" }, no_blur = true })

-- xwayland popups, ugh
hl.window_rule({ match = { xwayland = true, title = "win[0-9]+" }, tag = "+xwl_popup" })
hl.window_rule({
    match = { xwayland = true, title = "", class = "", initial_title = "", initial_class = "" },
    tag   = "+xwl_popup",
})
hl.window_rule({
    match     = { tag = "xwl_popup" },
    no_dim    = true,
    no_shadow = true,
    no_blur   = true,
    opaque    = true,
})

-- special workspaces
hl.window_rule({ match = { class = "btop" }, workspace = "special:sysmon" })
hl.window_rule({
    match     = {
        class = "feishin|Spotify|Supersonic|Cider|com.github.th_ch.youtube_music|Plexamp|com-maxrave-simpmusic-MainKt",
    },
    workspace = "special:music",
})
hl.window_rule({ match = { initial_title = "Spotify( \\(?Free\\)?)?" }, workspace = "special:music" }) -- spotify's wayland window has no class for some reason, match by title; hypr matches are re2, not lua patterns
hl.window_rule({ match = { class = "discord|equibop|vesktop|whatsapp|org\\.telegram\\.desktop|TelegramDesktop" }, workspace = "special:communication" })
hl.window_rule({ match = { class = "Todoist|io\\.github\\.alainm23\\.planify" }, workspace = "special:todo" })

-- layer rules

hl.layer_rule({ match = { namespace = "hyprpicker" }, animation = "fade" })                 -- hyprpicker fade out
hl.layer_rule({ match = { namespace = "logout_dialog" }, animation = "fade" })              -- wlogout
hl.layer_rule({ match = { namespace = "selection" }, animation = "fade" })                  -- slurp
hl.layer_rule({ match = { namespace = "wayfreeze" }, animation = "fade" })                  -- wayfreeze
hl.layer_rule({ match = { namespace = "launcher" }, animation = "popin 80%", blur = true }) -- fuzzel

-- pulse modules (osd bars, island, quick settings, the rest) draw their own entrances — keep the compositor out
-- (and off the osd's back); the power menu has no animation of its own, so just a soft fade
hl.layer_rule({ match = { namespace = "pulse-power" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "pulse-(launcher|edge|island|buds|quick|home|bar|caffeine|shot|clip|charms|vpn|deck|prefs|hot|cal|wall|back|switch|overview|snap|keys|jot)" }, no_anim = true })
