-- App: Flashlight for WADAMESH
-- Version: 1.1 (Added explicit theme-aware text coloring for day/night modes)

local app = {}

-- Flashlight state
local is_on = false
local mode = "WHITE" -- "WHITE" or "RED"
local brightness = 1.0 -- 0.2 to 1.0 in steps of 0.2

local canvas_obj = nil
local status_lbl = nil
local btn_power = nil
local btn_mode = nil

local function get_light_color()
    if not is_on then
        return 0x000000
    end

    if mode == "WHITE" then
        local val = math.floor(255 * brightness)
        return (val * 0x010000) + (val * 0x000100) + val
    else
        local red_val = math.floor(255 * brightness)
        return (red_val * 0x010000)
    end
end

local function redraw_light()
    if not canvas_obj or not app.last_w or not app.last_h then return end

    local w = app.last_w
    local h = app.last_h
    local C = wada.ui.colors

    local is_compact = (h <= 260)
    local header_h = is_compact and 70 or 95

    -- Canvas fill for light source
    local light_color = get_light_color()
    canvas_obj:rect(0, 0, w, h - header_h, light_color, true, 0)

    -- Update dynamic states
    if btn_power then
        local pwr_color = is_on and (C.good or 0x22c55e) or (C.bad or 0xef4444)
        if btn_power.bg then btn_power:bg(pwr_color) end
        if btn_power.color then btn_power:color(0xffffff) end -- Always white text on bright status buttons
        if btn_power.set then btn_power:set(is_on and "ON" or "OFF") end
    end

    if btn_mode then
        local mode_color = (mode == "WHITE") and (C.panel or 0x333333) or 0xcc2222
        if btn_mode.bg then btn_mode:bg(mode_color) end
        if btn_mode.color then btn_mode:color(C.text or 0xffffff) end
        if btn_mode.set then btn_mode:set(mode) end
    end

    if status_lbl and status_lbl.set then
        status_lbl:set("Level: " .. tostring(math.floor(brightness * 100)) .. "%")
    end
end

local function toggle_power()
    is_on = not is_on
    redraw_light()
end

local function toggle_mode()
    mode = (mode == "WHITE") and "RED" or "WHITE"
    redraw_light()
end

local function adjust_brightness(delta)
    brightness = brightness + delta
    if brightness > 1.0 then brightness = 1.0 end
    if brightness < 0.2 then brightness = 0.2 end
    redraw_light()
end

function app.on_open(w, h)
    w = w or 280
    h = h or 480
    app.last_w = w
    app.last_h = h

    local C = wada.ui.colors
    local is_compact = (h <= 260)
    local header_h = is_compact and 70 or 95

    wada.ui.label("FLASHLIGHT", 10, 6, is_compact and 12 or 16, C.text)

    status_lbl = wada.ui.label("Level: " .. tostring(math.floor(brightness * 100)) .. "%", 
                              w - 90, 8, is_compact and 10 or 12, C.accent)

    local ctrl_y = is_compact and 26 or 40
    local btn_h = is_compact and 32 or 40

    -- Power Toggle (On/Off)
    btn_power = wada.ui.button(is_on and "ON" or "OFF", 8, ctrl_y, 60, btn_h, toggle_power)
    if btn_power and btn_power.bg then 
        btn_power:bg(is_on and (C.good or 0x22c55e) or (C.bad or 0xef4444)) 
    end
    if btn_power and btn_power.color then btn_power:color(0xffffff) end

    -- Color Mode Toggle (White / Red)
    btn_mode = wada.ui.button(mode, 74, ctrl_y, 65, btn_h, toggle_mode)
    if btn_mode and btn_mode.bg then btn_mode:bg(C.panel or 0x333333) end
    if btn_mode and btn_mode.color then btn_mode:color(C.text) end

    -- Brightness decrease button [<]
    local btn_dec = wada.ui.button("<", w - 85, ctrl_y, 36, btn_h, function()
        adjust_brightness(-0.2)
    end)
    if btn_dec and btn_dec.bg then btn_dec:bg(C.panel or 0x333333) end
    if btn_dec and btn_dec.color then btn_dec:color(C.text) end

     -- Brightness increase button [>]
    local btn_inc = wada.ui.button(">", w - 44, ctrl_y, 36, btn_h, function()
        adjust_brightness(0.2)
    end)
    if btn_inc and btn_inc.bg then btn_inc:bg(C.panel or 0x333333) end
    if btn_inc and btn_inc.color then btn_inc:color(C.text) end

    -- Light Emitter Canvas
    local canvas_y = header_h
    local canvas_h = h - header_h
    canvas_obj = wada.ui.canvas(w, canvas_h)
    canvas_obj:pos(0, canvas_y)

    redraw_light()
end

function app.on_draw()
end

return app
