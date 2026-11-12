-- ============================================================================
-- WadeMesh Lua - Pomodoro Timer v2.6 (Dynamic Canvas Height Fix & 170px Back Button)
-- ============================================================================

local ui = wada.ui
local C = ui.colors
local app = {}

local focus_minutes = 25
local short_minutes = 5
local long_minutes = 15

local timer_label
local status_label
local mode_label
local session_label
local focus_label
local short_label
local long_label
local start_btn
local sleep_btn

local running = false
local seconds = 25 * 60
local duration = 25 * 60
local mode = "FOCUS"
local focus_sessions = 0
local start_ms = 0
local period_timer = nil
local zone = 0
local awake = false

-- Screen dimensions (default fallbacks, overridden dynamically in on_open)
local screen_w = 224
local screen_h = 320

local timer_canvas

-- Verified audio notification wrapper with return-status and fallback check
local function play_notification()
    local played = false
    
    if wada and wada.audio and wada.audio.play then
        local success, res = pcall(wada.audio.play, "sd:/Music/notification.mp3")
        if success and res ~= false and res ~= nil then
            played = true
        end
    end
    
    if not played then
        if wada and wada.sys and wada.sys.beep then
            wada.sys.beep(1000, 300)
        end
    end
end

local function start_period_timer()
    if period_timer then
        period_timer:stop()
    end
    period_timer = wada.timer.after(
        seconds * 1000,
        function()
            seconds = 0
            play_notification()

            local is_compact = (screen_h <= 350)
            local canvas_h = is_compact and 48 or 55

            if mode == "FOCUS" then
                focus_sessions = focus_sessions + 1
                if session_label then
                    session_label:set(string.format("Focus Sessions: %d", focus_sessions))
                end

                if focus_sessions % 4 == 0 then
                    mode = "LONG BREAK"
                    duration = long_minutes * 60
                    if mode_label then mode_label:set("LONG BREAK") end
                    if timer_canvas then timer_canvas:rect(0, 0, 200, canvas_h, C.sub, true, 6) end
                else
                    mode = "SHORT BREAK"
                    duration = short_minutes * 60
                    if mode_label then mode_label:set("SHORT BREAK") end
                    if timer_canvas then timer_canvas:rect(0, 0, 200, canvas_h, C.good, true, 6) end
                end
            else
                mode = "FOCUS"
                duration = focus_minutes * 60
                if mode_label then mode_label:set("FOCUS") end
                if timer_canvas then timer_canvas:rect(0, 0, 200, canvas_h, C.bad, true, 6) end
            end

            seconds = duration
            if timer_label then
                timer_label:set(string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60))
            end
            start_ms = wada.sys.millis()
            if status_label then status_label:set("RUNNING") end
            start_period_timer()
        end
    )
end

-- Forward declarations
local show_settings
local show_timer

-- Timer screen implementation
show_timer = function()
    ui.clear()
    
    local is_compact = (screen_h <= 350)
    local canvas_h = is_compact and 48 or 55
    
    timer_canvas = ui.canvas(200, canvas_h)
    timer_canvas:pos(math.floor((screen_w - 200) / 2), is_compact and 34 or 50)
    
    -- Preserve correct canvas color based on active mode
    local canvas_color = C.bad
    if mode == "SHORT BREAK" then canvas_color = C.good
    elseif mode == "LONG BREAK" then canvas_color = C.sub end
    timer_canvas:rect(0, 0, 200, canvas_h, canvas_color, true, 6)

    local center_width = screen_w - 16
    local button_width = math.floor((screen_w - 30) / 2)
    local left_x = 10

    -- Auto-sync duration if settings changed while stopped
    if not running then
        if mode == "FOCUS" then duration = focus_minutes * 60
        elseif mode == "SHORT BREAK" then duration = short_minutes * 60
        elseif mode == "LONG BREAK" then duration = long_minutes * 60 end
        seconds = duration
    end

    mode_label = ui.label(mode, 10, is_compact and 6 or 15, 16, C.accent)
    mode_label:width(center_width, "center")

    timer_label = ui.label(
        string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60),
        10, is_compact and 44 or 65, 24, C.text    
    )
    timer_label:width(center_width, "center")

    status_label = ui.label(running and "RUNNING" or "PAUSED", 10, is_compact and 92 or 115, 12, C.text)
    status_label:width(center_width, "center")

    local btn_y = is_compact and 114 or 160
    local btn_h = is_compact and 34 or 40

    -- Start / Pause Button with dynamic text toggling
    start_btn = ui.button(
        running and "PAUSE" or "START",
        left_x, btn_y, button_width, btn_h,
        function()
            running = not running
            if running then
                start_ms = wada.sys.millis() - ((duration - seconds) * 1000)
                status_label:set("RUNNING")
                start_btn:set("PAUSE")
                start_period_timer()
            else
                status_label:set("PAUSED")
                start_btn:set("START")
                if period_timer then
                    period_timer:stop()
                    period_timer = nil
                end
            end
        end
    )

    ui.button(
        "RESET",
        left_x + button_width + 10, btn_y, button_width, btn_h,
        function()
            running = false
            mode = "FOCUS"
            duration = focus_minutes * 60
            seconds = duration
            focus_sessions = 0
            if period_timer then
                period_timer:stop()
                period_timer = nil
            end
            mode_label:set("FOCUS")
            timer_label:set(string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60))
            status_label:set("PAUSED")
            if timer_canvas then timer_canvas:rect(0, 0, 200, canvas_h, C.bad, true, 6) end
            if start_btn then start_btn:set("START") end
            if session_label then session_label:set("Focus Sessions: 0") end
        end
    )

    session_label = ui.label(
        string.format("Focus Sessions: %d", focus_sessions),
        10, is_compact and 156 or 215, 12, C.sub
    )
    session_label:width(center_width, "center")

    ui.button(
        "SETTINGS",
        math.floor((screen_w - 120) / 2), is_compact and 178 or 260, 120, btn_h,
        function()
            show_settings()
        end
    )
end

-- Settings screen implementation with integrated button state indicators
show_settings = function()
    ui.clear()

    local is_compact = (screen_h <= 350)

    ui.label("TIMER SETTINGS", 8, is_compact and 4 or 8, 14, C.accent):width(screen_w - 16, "center")

    focus_label = ui.label(string.format("%d MIN", focus_minutes), 8, is_compact and 22 or 40, 18, C.text)
    focus_label:width(screen_w - 16, "center")
    ui.label("FOCUS", 8, is_compact and 42 or 70, 10, C.accent):width(screen_w - 16, "center")

    short_label = ui.label(string.format("%d MIN", short_minutes), 8, is_compact and 56 or 95, 18, C.text)
    short_label:width(screen_w - 16, "center")
    ui.label("SHORT BREAK", 8, is_compact and 76 or 125, 10, C.accent):width(screen_w - 16, "center")

    long_label = ui.label(string.format("%d MIN", long_minutes), 8, is_compact and 90 or 150, 18, C.text)
    long_label:width(screen_w - 16, "center")
    ui.label("LONG BREAK(1:4)", 8, is_compact and 110 or 180, 10, C.accent):width(screen_w - 16, "center")

    status_label = ui.label("Swipe over value to change", 8, is_compact and 130 or 210, 9, C.sub)
    status_label:width(screen_w - 16, "center")

    local btn_h = is_compact and 30 or 36
    
    ui.button(
        "BACK TO TIMER",
        math.floor((screen_w - 170) / 2), is_compact and 148 or 240, 170, btn_h,  -- widened to 170px
        function()
            show_timer()
        end
    )

    -- Stateful Sleep Toggle Button
    sleep_btn = ui.button(
        awake and "SLEEP: OFF" or "SLEEP: ON",
        math.floor((screen_w - 150) / 2), is_compact and 184 or (screen_h - 50), 150, btn_h,
        function()
            awake = not awake
            if awake then
                wada.sys.keep_awake(true)
                sleep_btn:set("SLEEP: OFF")
            else
                wada.sys.keep_awake(false)
                sleep_btn:set("SLEEP: ON")
            end
            wada.sys.beep(1000, 100)
        end
    )
end

-- Touch Input handling for swipe adjustments
function app.on_input(ev)
    if ev.type == "down" then
        zone = ev.y
    elseif ev.type == "swipe" then
        local direction = tostring(ev.dir)
        local is_compact = (screen_h <= 350)
        
        local z1 = is_compact and 50 or 70
        local z2 = is_compact and 90 or 125
        local z3 = is_compact and 130 or 180

        if zone < z1 then
            if direction == "right" and focus_minutes < 60 then focus_minutes = focus_minutes + 1
            elseif direction == "left" and focus_minutes > 1 then focus_minutes = focus_minutes - 1 end
        elseif zone < z2 then
            if direction == "right" and short_minutes < 15 then short_minutes = short_minutes + 1
            elseif direction == "left" and short_minutes > 1 then short_minutes = short_minutes - 1 end
        elseif zone < z3 then
            if direction == "right" and long_minutes < 30 then long_minutes = long_minutes + 1
            elseif direction == "left" and long_minutes > 1 then long_minutes = long_minutes - 1 end
        end

        if focus_label then
            focus_label:set(string.format("%d MIN", focus_minutes))
            short_label:set(string.format("%d MIN", short_minutes))
            long_label:set(string.format("%d MIN", long_minutes))
        end
    end
end

-- Ticker loop update
function app.on_tick()
    if running then
        local now_ms = wada.sys.millis()
        local elapsed = math.floor((now_ms - start_ms) / 1000)
        local remaining = duration - elapsed
        if remaining < 0 then remaining = 0 end
        seconds = remaining
        
        if timer_label then
            timer_label:set(string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60))
        end
    end
end

-- App Open Initialization Lifecycle
function app.on_open(w, h)
    screen_w = w or 224
    screen_h = h or 320
    duration = focus_minutes * 60
    seconds = duration
    wada.timer.every(1000)
    show_timer()
end

return app