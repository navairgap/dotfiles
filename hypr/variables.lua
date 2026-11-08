local scheme = require("scheme.pulse")
local home   = os.getenv("HOME")

-- PULSE_NESTED=1 Hyprland -c …/rice/config/hypr/hyprland.lua runs a nested session for debugging:
-- the system daemons are already running outside
local nested = os.getenv("PULSE_NESTED") ~= nil
-- which shell is live is rice's call: `rice switch <name>` or the Rice app.
-- full path: ~/.local/bin isn't on hypr's PATH
local rice   = home .. "/.config/quickshell/rice/rice"

return {
    ------------------
    ---- HYPRLAND ----
    ------------------

    nested                     = nested,

    -- Shell
    rice                       = rice,
    lockCmd                    = rice .. " lock", -- lock via the current shell; won't spawn a second one

    -- Apps
    terminal                   = "kitty", -- not -1: the shared process broke GL after sleep (amd and intel) and blanked every new window until reboot (#12); costs ~230 ms instead of ~20
    browser                    = "zen-browser",
    fileExplorer               = "thunar",
    audioSettings              = "pavucontrol",
    -- the special workspace programs (launched when the ws is empty) and the editor. binds read these on keypress,
    -- so override them in user.lua: require("variables").apps.editor = "codium". unset means an empty
    -- workspace opens. install.sh --with adds telegram and spotify
    apps                       = {
        sysmon        = "kitty --class btop -T btop btop",
        music         = "spotify-launcher",
        communication = "Telegram",
    },

    -- Touchpad
    touchpadDisableTyping      = false,
    touchpadScrollFactor       = 0.3,
    gestureFingers             = 4,
    workspaceSwipeFingers      = 3,
    gestureFingersMore         = 5,

    -- Blur
    blurEnabled                = true,
    blurSpecialWs              = false,
    blurPopups                 = true,
    blurInputMethods           = true,
    blurSize                   = 8,
    blurPasses                 = 2,
    blurXray                   = false,

    -- Shadow
    -- a faint red glow on the focused window
    shadowEnabled              = true,
    shadowRange                = 10,
    shadowRenderPower          = 4,
    shadowColour               = "rgba(" .. scheme.crimson .. "20)",

    -- Gaps
    workspaceGaps              = 15,
    windowGapsIn               = 6,
    windowGapsOut              = 14,

    -- Window styling
    windowOpacity              = 1,
    windowRounding             = 0,
    windowBorderSize           = 2,
    activeWindowBorderColour   = {
        colors = { "rgb(" .. scheme.crimson .. ")", "rgb(" .. scheme.rose .. ")", "rgb(" .. scheme.crimson .. ")" },
        angle = 135,
    },
    inactiveWindowBorderColour = "rgb(" .. scheme.wine .. ")",

    -- Misc
    volumeStep                 = 5,
    volumeMax                  = 100,
    cursorTheme                = "Bibata-Modern-Classic",
    cursorSize                 = 23,
    sleepGestureCmd            = "systemctl suspend-then-hibernate || systemctl suspend", -- no hibernate here, plain suspend

    ------------------
    ---- KEYBINDS ----
    ------------------

    -- Workspaces
    kbMoveWinToWs              = "SUPER + ALT",
    kbMoveWinToWsGroup         = "CTRL + SUPER + ALT",
    kbGoToWs                   = "SUPER",
    kbGoToWsGroup              = "CTRL + SUPER",
    kbNextWs                   = "CTRL + SUPER + Right",
    kbPrevWs                   = "CTRL + SUPER + Left",

    -- Window Switcher and Groups
    kbSwitcherNext             = "ALT + Tab",
    kbSwitcherPrev             = "SHIFT + ALT + Tab",
    kbSwitcherSuperNext        = "SUPER + Tab",
    kbSwitcherSuperPrev        = "SUPER + SHIFT + Tab",
    kbSwitcherCancel           = "ALT + Escape",
    kbOverview                 = "SUPER + CTRL + Up",
    kbUngroup                  = "SUPER + U",
    kbToggleGroup              = "SUPER + Comma",

    -- Window Action
    kbMoveWindow               = "SUPER + Z",
    kbResizeWindow             = "SUPER + X",
    kbWindowPip                = "SUPER + ALT + backslash",
    kbPinWindow                = "SUPER + SHIFT + P", -- super+p is taken by the vpn pact
    kbWindowFullscreen         = "SUPER + F",
    kbWindowBorderedFullscreen = "SUPER + ALT + F",
    kbToggleWindowFloating     = "SUPER + ALT + space",
    kbCloseWindow              = "SUPER + C",

    -- Special workspaces toggles
    kbSpecialWs                = "SUPER + S",
    kbSystemMonitorWs          = "CTRL + SHIFT + Escape",
    kbMusicWs                  = "SUPER + M",
    kbCommunicationWs          = "SUPER + D",
    kbTodoWs                   = "SUPER + R",

    -- Apps
    kbTerminal                 = "SUPER + Q",
    kbBrowser                  = "SUPER + W",
    kbEditor                   = "SUPER + SHIFT + K",
    kbFileExplorer             = "SUPER + E",

    -- Misc
    kbSession                  = "CTRL + ALT + Delete",
    kbPower                    = "SUPER + Escape",
    kbAltar                    = "SUPER + Space",
    kbLock                     = "SUPER + L",
    kbRestoreLock              = "SUPER + ALT + L",
}
