local vars = require("variables")

local function wsaction(action, range, i)
    return function()
        local activews = hl.get_active_workspace()
        if activews then
            local id = activews.id
            -- "group" range: same last digit in group i-1; otherwise the i-th ws of the current group
            local peer   = (i - 1) * 10 + (id % 10)
            local within = math.floor((id - 1) / 10) * 10 + i
            local target = (range == "group") and peer or within

            if action == "move" then
                return hl.dispatch(hl.dsp.window.move({ workspace = target }))
            else
                return hl.dispatch(hl.dsp.focus({ workspace = target }))
            end
        end
    end
end

local function resize_by_screen(x, y)
    local screen = hl.get_active_monitor()
    if screen and type(screen.width) == "number" and type(screen.height) == "number" then
        if not (x == 0 and y == 0) then
            local w = (x and x > 0) and math.floor(screen.width * x / 100) or screen.width
            local h = (y and y > 0) and math.floor(screen.height * y / 100) or screen.height
            return { x = w, y = h, relative = false }
        end
    end
end

local function resize_active_window(x, y)
    local win = hl.get_active_window()
    if win and win.size then
        local w = (win.size.x * (x / 100)) or 800
        local h = (win.size.y * (y / 100)) or 600

        return { x = w, y = h, relative = true }
    end
end

local function resizer(window, pattern, x_percent, y_percent, actions, exact)
    if (window and window.title) and string.find(window.title, pattern, 1, exact) then
        local disp = (type(actions) == "table") and actions or { actions }
        for _, x in ipairs(disp) do
            hl.dispatch(x)
        end

        hl.dispatch(hl.dsp.window.resize(resize_by_screen(x_percent, y_percent)))
        hl.dispatch(hl.dsp.window.set_prop({ prop = "keep_aspect_ratio", value = "true" }))
    end
end

local function move_actions(win)
    local screen = hl.get_active_monitor()

    if screen and screen.width and screen.height and win and win.size then
        local monitor_height = screen.height / screen.scale
        local monitor_width  = screen.width / screen.scale

        local scale_factor   = (monitor_height / 4) / win.size.y

        local target_width   = win.size.x * scale_factor
        local target_height  = win.size.y * scale_factor

        local x_resize       = math.floor(math.max(200, target_width))
        local y_resize       = math.floor(math.max(150, target_height))

        local offset         = math.min(monitor_width, monitor_height) * 0.03

        local move_x         = math.floor(screen.x + monitor_width - x_resize - offset)
        local move_y         = math.floor(screen.y + monitor_height - y_resize - offset)

        return {
            hl.dsp.window.resize({ x = x_resize, y = y_resize, window = win }),
            hl.dsp.window.move({ x = move_x, y = move_y, relative = false, window = win }),
        }
    end
end

-- snap the active window to a zone of the active monitor and float it: fx/fy top-left in %, fw/fh size in %
-- (0 means the full edge). a snapped window stands still, windows-snap style — dwindle would drag a tiled one back.
-- the shell flashes the same zone (pulse/snap), the fraction tables must match zone for zone
local function snap_active(fx, fy, fw, fh)
    local mon = hl.get_active_monitor()
    if not (mon and mon.width and mon.height) then return end
    hl.dispatch(hl.dsp.window.float({ action = "on" }))
    hl.dispatch(hl.dsp.window.resize({
        x = math.floor(mon.width * (fw > 0 and fw or 100) / 100),
        y = math.floor(mon.height * (fh > 0 and fh or 100) / 100),
        relative = false,
    }))
    hl.dispatch(hl.dsp.window.move({
        x = math.floor(mon.x + mon.width * fx / 100),
        y = math.floor(mon.y + mon.height * fy / 100),
        relative = false,
    }))
end

-- special workspaces: toggle, and when the ws is empty launch its app from vars.apps (stands in for caelestia's toggle).
-- apps are read on keypress, not at load: user.lua loads after the binds and swaps them there
local function toggle_special(name)
    return function()
        local cmd = vars.apps[name]
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.name == "special:" .. name and ws.windows > 0 then cmd = nil end
        end
        -- show the ws before launching: hypr opens the window wherever focus was at launch time,
        -- and in the other order it would hide the workspace the moment the window appeared
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
        if cmd then hl.exec_cmd(cmd) end
    end
end

-- screen recording with gpu-screen-recorder; hit the same bind again to stop
local function record(region, sound)
    return function()
        local mon = hl.get_active_monitor()
        local src = region and '-w region -region "$(slurp -f %wx%h+%x+%y)"' or "-w " .. (mon and mon.name or "region")
        hl.exec_cmd("pkill -INT -f '^gpu-screen-recorder' || gpu-screen-recorder " .. src ..
            (sound and " -a default_output" or "") .. ' -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"')
    end
end

return {
    toggle_special       = toggle_special,
    record               = record,
    resizer              = resizer,
    resize_by_screen     = resize_by_screen,
    resize_active_window = resize_active_window,
    snap_active          = snap_active,
    wsaction             = wsaction,
    move_actions         = move_actions,
}
