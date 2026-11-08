local scheme = require("scheme.pulse")

hl.config({
    misc = {
        animate_manual_resizes       = false,
        animate_mouse_windowdragging = false,

        disable_hyprland_logo        = true,
        force_default_wallpaper      = 0,

        on_focus_under_fullscreen    = 2,
        allow_session_lock_restore   = true,
        middle_click_paste           = false,
        focus_on_activate            = true,
        session_lock_xray            = true,

        mouse_move_enables_dpms      = true,
        key_press_enables_dpms       = true,

        background_color             = "rgb(" .. scheme.void .. ")",
    },

    -- no auto hdr: a fullscreen chromium/electron window would flip the panel into hdr — modeset (screen blinks,
    -- ~1 s with the compositor frozen) and sdr content comes out darker
    render = {
        cm_auto_hdr = 0,
    },

    debug = {
        error_position = 1
    }
})
