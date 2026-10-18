-- App: Calculator for WADAMESH (LilyGO P4)
-- Version: 9.0 (Updated with Beta 96 button:bg support)
-- This is a beta version, Use at your own risk.  10/17/26 

local app = {}

local current_input = "0"
local first_operand = nil
local pending_op = nil
local reset_next = false

local display_lbl = nil
local status_lbl = nil

local MAX_INPUT_LEN = 16

local function format_number(num)
    if type(num) ~= "number" then return tostring(num) end
    if num ~= num then return "Error" end
    if num == math.huge or num == -math.huge then return "Overflow" end

    local s = string.format("%.11g", num)
    s = string.gsub(s, "e%+0+(%d+)", "e+%1")
    s = string.gsub(s, "e%-0+(%d+)", "e-%1")
    return s
end

local function update_display()
    if display_lbl then
        local disp = current_input
        if #disp > MAX_INPUT_LEN then
            disp = string.sub(disp, 1, MAX_INPUT_LEN)
        end
        display_lbl:set(disp)
    end
    if status_lbl then
        if pending_op and first_operand then
            local op_str = format_number(first_operand)
            if #op_str > 12 then op_str = string.sub(op_str, 1, 10) .. "…" end
            status_lbl:set(op_str .. " " .. pending_op)
        else
            status_lbl:set("")
        end
    end
end

local function evaluate()
    if not first_operand or not pending_op then return end
    local second = tonumber(current_input) or 0
    local result = 0

    if pending_op == "+" then result = first_operand + second
    elseif pending_op == "-" then result = first_operand - second
    elseif pending_op == "*" then result = first_operand * second
    elseif pending_op == "/" then 
        result = (second ~= 0) and (first_operand / second) or "Error"
    end

    current_input = format_number(result)
    first_operand = nil
    pending_op = nil
    reset_next = true
    update_display()
end

local function handle_key(key)
    if key >= "0" and key <= "9" then
        if current_input == "0" or current_input == "Error" or current_input == "Overflow" or reset_next then
            current_input = key
            reset_next = false
        else
            if #current_input < MAX_INPUT_LEN then
                current_input = current_input .. key
            end
        end
    elseif key == "." then
        if reset_next or current_input == "Error" or current_input == "Overflow" then
            current_input = "0."
            reset_next = false
        elseif not string.find(current_input, "%.") then
            if #current_input < MAX_INPUT_LEN then
                current_input = current_input .. "."
            end
        end
    elseif key == "%" then
        local val = tonumber(current_input) or 0
        current_input = format_number(val / 100)
        reset_next = true
    elseif key == "+/-" then
        if current_input ~= "0" and current_input ~= "Error" and current_input ~= "Overflow" then
            if string.sub(current_input, 1, 1) == "-" then
                current_input = string.sub(current_input, 2)
            else
                if #current_input < MAX_INPUT_LEN + 1 then
                    current_input = "-" .. current_input
                end
            end
        end
    elseif key == "C" then
        current_input = "0"
        first_operand = nil
        pending_op = nil
        reset_next = false
    elseif key == "DEL" then
        if current_input == "Error" or current_input == "Overflow" or reset_next then
            current_input = "0"
            reset_next = false
        elseif #current_input > 1 then
            current_input = string.sub(current_input, 1, -2)
            if current_input == "-" then current_input = "0" end
        else
            current_input = "0"
        end
    elseif key == "+" or key == "-" or key == "*" or key == "/" then
        if pending_op and not reset_next then evaluate() end
        first_operand = tonumber(current_input) or 0
        pending_op = key
        reset_next = true
    elseif key == "=" or key == "\n" or key == "\r" then
        evaluate()
    end
    update_display()
end

function app.on_open(w, h)
    w = w or 280
    h = h or 480
    current_input = "0"
    first_operand = nil
    pending_op = nil
    reset_next = false

    local C = wada.ui.colors

    local is_compact = (h <= 260)
    local usable_w = is_compact and math.min(w - 12, 280) or math.min(w - 20, 240)
    local start_x = math.floor((w - usable_w) / 2)
    local display_y = is_compact and 4 or 15
    local display_h = is_compact and 32 or 55
    local row_gap = is_compact and 2 or 4
    local grid_top = display_y + display_h + (is_compact and 4 or 12)

    -- Display canvas
    local cv_w = math.min(w, 480)
    local cv_h = math.min(h, 480)
    local cv = wada.ui.canvas(cv_w, cv_h)
    cv:pos(0, 0)

    -- Status equation line & main readout label
    local stat_sz = is_compact and 9 or 10
    local disp_sz = is_compact and 14 or 16
    status_lbl = wada.ui.label("", start_x + 10, display_y + (is_compact and 2 or 6), stat_sz, C.sub)
    display_lbl = wada.ui.label("0", start_x + 10, display_y + (is_compact and 14 or 24), disp_sz, C.text)

    -- Button Matrix Layout
    local buttons = {
        {"C",  "%",  "DEL", "/"},
        {"7",  "8",  "9",   "*"},
        {"4",  "5",  "6",   "-"},
        {"1",  "2",  "3",   "+"},
        {"0",  ".",  "+/-", "="}
    }

    local cols, rows = 4, 5
    local btn_w = math.floor(usable_w / cols)
    local avail_h = h - grid_top - (is_compact and 4 or 12)
    local btn_h = math.floor((avail_h - (rows - 1) * row_gap) / rows)
    if btn_h > 45 then btn_h = 45 end
    if btn_h < 22 then btn_h = 22 end
    local grid_bottom = grid_top + rows * btn_h + (rows - 1) * row_gap

    -- Draw outline box around all features, then draw display box
    cv:rect(0, 0, w, grid_bottom, C.accent or 0x15b6a6, true, is_compact and 8 or 15)
    cv:rect(start_x, display_y, usable_w, display_h, C.panel or 0x15181b, true, is_compact and 5 or 8)

    -- Draw buttons
    for r = 1, rows do
        for c = 1, cols do
            local label = buttons[r][c]
            local x = start_x + (c - 1) * btn_w
            local y = grid_top + (r - 1) * (btn_h + row_gap)

            -- Create button and capture handle reference
            local btn = wada.ui.button(label, x + 1, y + 1, btn_w - 2, btn_h - 2, function()
                handle_key(label)
            end)

            -- Apply custom background colors using Beta 96 button:bg() feature (safely guarded)
            if btn and btn.bg then
                if label == "+" or label == "-" or label == "*" or label == "/" or label == "=" then
                    -- Operators get primary/accent theme styling
                    btn:bg(0xcc6622 or C.primary)
                elseif label == "C" or label == "DEL" or label == "%" or label == "+/-" then
                    -- Function keys get a distinct secondary style
                    btn:bg(C.sub or C.panel)
                else
                    -- Number keys use standard panel background
                    btn:bg(C.panel)
                end
            end
        end
    end
end

function app.on_input(ev)
    if not ev then return end
    if ev.type == "key" then
        local k = ev.key
        if k == "backspace" or k == "del" or k == "\b" then
            handle_key("DEL")
        elseif k == "enter" or k == "\n" or k == "\r" or k == "=" then
            handle_key("=")
        elseif k == "c" or k == "C" or k == "escape" then
            handle_key("C")
        elseif k == "p" or k == "P" then
            handle_key("+/-")
        else
            handle_key(k)
        end
    end
end

function app.on_draw()
end

return app