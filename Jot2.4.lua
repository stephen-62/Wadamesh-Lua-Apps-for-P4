-- App: Checklist for WADAMESH (LilyGO P4)
-- Version: 2.4 (Unified string persistence for reliable saving)

local app = {}

local SYM_BOX     = "\xE2\x80\xA2"  -- or  "[ ]"
local SYM_CHECKED = "\xEF\x80\x8C"   --or  "[X]"

local items = {
    { text = "Check Radio Antenna", checked = false },
    { text = "Verify Mesh Node ID", checked = false },
    { text = "Charge P4 Battery",   checked = false }
}

local check_btns = {}
local progress_lbl = nil

-- Save all state into a single encoded string to ensure store reliability
local function save_state()
    if wada and wada.store then
        local parts = {}
        for _, item in ipairs(items) do
            local status = item.checked and "1" or "0"
            -- Replace any potential pipe characters in user text to avoid delimiter collision
            local clean_txt = string.gsub(item.text, "|", "-")
            table.insert(parts, status .. ":" .. clean_txt)
        end
        local encoded = table.concat(parts, "|")
        wada.store.set("checklist_data", encoded)
    end
end

-- Load state from the single unified key
local function load_state()
    if wada and wada.store then
        local encoded = wada.store.get("checklist_data")
        if encoded and #encoded > 0 then
            items = {}
            for pair in string.gmatch(encoded, "([^|]+)") do
                local checked_flag, text = string.match(pair, "^([01]):(.+)$")
                if checked_flag and text then
                    table.insert(items, {
                        text = text,
                        checked = (checked_flag == "1")
                    })
                end
            end
            if #items == 0 then    -- Test data to initialize database 
                items = {
                    { text = "Check Radio Antenna", checked = false },
                    { text = "Verify Mesh Node ID", checked = false },
                    { text = "Charge P4 Battery",   checked = false }
                }
            end
        end
    end
end

local function btn_set(btn, text)
    if btn then
        if btn.set then btn:set(text) end
        if btn.set_text then btn:set_text(text) end
    end
end

local function update_progress()
    local done = 0
    for _, item in ipairs(items) do
        if item.checked then done = done + 1 end
    end

    if progress_lbl then
        progress_lbl:set(tostring(done) .. " of " .. tostring(#items) .. " Done")
    end
end

local function toggle_item(index)
    local item = items[index]
    local btn = check_btns[index]
    if not item or not btn then return end

    item.checked = not item.checked
    btn_set(btn, item.checked and SYM_CHECKED or SYM_BOX)

    local C = wada.ui.colors
    if btn.color then
        btn:color(item.checked and C.accent or C.sub)
    end

    update_progress()
    save_state()
end

local function add_new_task()
    if wada.ui.input then
        wada.ui.input("New Checklist Item", "", function(text)
            if text and #text > 0 then
                table.insert(items, { text = text, checked = false })
                save_state()
                if app.last_w and app.last_h then
                    app.on_open(app.last_w, app.last_h)
                end
            end
        end)
    end
end

local function delete_task(index)
    if items[index] then
        table.remove(items, index)
        save_state()
        if app.last_w and app.last_h then
            app.on_open(app.last_w, app.last_h)
        end
    end
end

function app.on_open(w, h)
    w = w or 280
    h = h or 480
    app.last_w = w
    app.last_h = h

    load_state()

    local C = wada.ui.colors
    local is_compact = (h <= 260)

    local usable_w = is_compact and math.min(w - 8, 280) or math.min(w - 20, 240)     -- changed math.min(w-12,280) to (w-8,280)
    local start_x = math.floor((w - usable_w) / 2)
    local header_y = is_compact and 6 or 12
    local header_h = is_compact and 36 or 52

    if wada.ui.scroll then wada.ui.scroll(true) end

    local cv_w = math.min(w, 480)
    local cv_h = math.max(h, #items * 50 + 120)
    local cv = wada.ui.canvas(cv_w, cv_h)
    cv:pos(0, 0)

    cv:rect(start_x, header_y, usable_w, header_h, C.panel or 0x15181b, true, 8)

    wada.ui.label("CHECKLIST", start_x + 12, header_y + 8, is_compact and 12 or 16, C.text)
    progress_lbl = wada.ui.label("", start_x + 12, header_y + (is_compact and 22 or 32), is_compact and 9 or 10, C.accent)

    local add_btn_w = is_compact and 45 or 55
    local add_btn = wada.ui.button("Add", start_x + usable_w - add_btn_w - 6, header_y + 8, add_btn_w, header_h - 16, add_new_task)
    if add_btn and add_btn.bg then add_btn:bg(C.primary or C.accent) end

    local row_top = header_y + header_h + 10
    local row_h = is_compact and 32 or 40
    local row_gap = 6
    local box_btn_w = is_compact and 36 or 40
    local del_btn_w = is_compact and 28 or 32

    check_btns = {}

    for i, item in ipairs(items) do
        local y = row_top + (i - 1) * (row_h + row_gap)

        cv:rect(start_x, y, usable_w, row_h, C.panel or 0x15181b, true, 6)

        local symbol = item.checked and SYM_CHECKED or SYM_BOX
        local btn = wada.ui.button(symbol, start_x + 4, y + 4, box_btn_w, row_h - 8, function()
            toggle_item(i)
        end)

        if btn and btn.bg then btn:bg(C.bg or 0x000000) end
        if btn and btn.color then btn:color(item.checked and C.accent or C.sub) end
        check_btns[i] = btn

        local disp_text = item.text
        if #disp_text > 18 then disp_text = string.sub(disp_text, 1, 16) .. "…" end
        wada.ui.label(disp_text, start_x + box_btn_w + 10, y + math.floor((row_h - 14) / 2), is_compact and 10 or 12, C.text)

        local del_btn = wada.ui.button("X", start_x + usable_w - del_btn_w - 4, y + 4, del_btn_w, row_h - 8, function()
            delete_task(i)
        end)

        if del_btn and del_btn.bg then del_btn:bg(C.bad or 0xcc3333) end
    end

    update_progress()
end

function app.on_draw()
end

return app
