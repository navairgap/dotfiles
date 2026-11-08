local vars = require("variables")

hl.config({
    input = {
        kb_layout          = "us,ru",
        kb_options         = "grp:alt_shift_toggle",
        numlock_by_default = false,
        repeat_delay       = 250,
        repeat_rate        = 35,
        focus_on_close     = 1, -- focus the nearest window on close, not the last focused

        touchpad           = {
            natural_scroll       = true,
            disable_while_typing = vars.touchpadDisableTyping,
            scroll_factor        = vars.touchpadScrollFactor,
        },
    },

    binds = {
        scroll_event_delay = 0, -- no throttle on wheel events
    },

    cursor = {
        hotspot_padding = 1,
    },
})
