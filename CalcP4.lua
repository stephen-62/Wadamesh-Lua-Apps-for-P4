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

local function update_display()
    if display_lbl then display_lbl:set(current_input) end
    if status_lbl then
        if pending_op and first_operand then
            status_lbl:set(tostring(first_operand) .. " " .. pending_op)
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

    if type(result) == "number" then
        result = math.floor(result * 100000 + 0.5) / 100000
        current_input = tostring(result)
    else
        current_input = result
    end

    first_operand = nil
    pending_op = nil
    reset_next = true
    update_display()
end

local function handle_key(key)
    if key >= "0" and key <= "9" then
        if current_input == "0" or current_input == "Error" or reset_next then
            current_input = key
            reset_next = false
        else
            current_input = current_input .. key
        end
    elseif key == "." then
        if reset_next or current_input == "Error" then
            current_input = "0."
            reset_next = false
        elseif not string.find(current_input, "%.") then
            current_input = current_input .. "."
        end
    elseif key == "%" then
        local val = tonumber(current_input) or 0
        current_input = tostring(val / 100)
        reset_next = true
    elseif key == "+/-" then
        if current_input ~= "0" and current_input ~= "Error" then
            if string.sub(current_input, 1, 1) == "-" then
                current_input = string.sub(current_input, 2)
            else
                current_input = "-" .. current_input
            end
        end
    elseif key == "C" then
        current_input = "0"
        first_operand = nil
        pending_op = nil
        reset_next = false
    elseif key == "DEL" then
        if current_input == "Error" or reset_next then
            current_input = "0"
            reset_next = false
        elseif #current_input > 1 then
            current_input = string.sub(current_input, 1, -2)
        else
            current_input = "0"
        end
    elseif key == "+" or key == "-" or key == "*" or key == "/" then
        if pending_op and not reset_next then evaluate() end
        first_operand = tonumber(current_input) or 0
        pending_op = key
        reset_next = true
    elseif key == "=" then
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

    -- Centered layout bounds for the 240px grid
    local usable_w = 240
    local start_x = math.floor((w - usable_w) / 2)
    local display_y = 15
    local display_h = 55

    -- Display panel box
    --local cv = wada.ui.canvas(usable_w, display_h)
    local cv= wada.ui.canvas(w,h-100)
    --if cv.pos then cv:pos(start_x, display_y) end
    cv:pos(0,0)

    -- Status equation line & main readout label
    status_lbl = wada.ui.label("", start_x + 12, display_y + 6, 10, C.sub)
    display_lbl = wada.ui.label("0", start_x + 12, display_y + 24, 16, C.text)

    -- Button Matrix Layout
    local buttons = {
        {"C",  "%",  "DEL", "/"},
        {"7",  "8",  "9",   "*"},
        {"4",  "5",  "6",   "-"},
        {"1",  "2",  "3",   "+"},
        {"0",  ".",  "+/-", "="}
    }

    local grid_top = display_y + display_h + 12
    local cols, rows = 4, 5
    local btn_w = usable_w / cols
    local btn_h = 45
    local grid_bottom= grid_top+ rows*(btn_h+4) +12

    -- draw outline box around all features, then draw display box
    cv:rect(0, 0, w, grid_bottom, C.accent, true, 15)
    cv:rect(start_x, display_y, usable_w, display_h, C.panel, true, 8)
    -- Draw buttons 

    for r = 1, rows do
        for c = 1, cols do
            local label = buttons[r][c]
            local x = start_x + (c - 1) * btn_w
            local y = grid_top + (r - 1) * (btn_h + 4)

            -- Create button and capture handle reference
            local btn = wada.ui.button(label, x + 2, y + 2, btn_w - 4, btn_h - 4, function()
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

function app.on_draw()
end

return app