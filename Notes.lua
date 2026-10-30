--Notes Version 2.4 by rock.paper.sissors and Gemini Argon to debug.  

local app = {}
local notes = {}
local input_string = ""

local C = wada.ui.colors

function app.on_input(ev)
  if ev.type == "key" then
    if ev.key == "_" then
      return
    else
      input_string = input_string .. ev.key
    end
  end
end

local function get_board_size()
  local sys = wada.sys.board()
  return sys.w or 240, sys.h or 320
end

local function reset_ui()
  wada.ui.clear()
  read_notes()
  local w, h = get_board_size()
  create_ui(w, h)
end

function check_if_exists_in_notes(note)
  return wada.fs.read(note) ~= nil
end

function more_names(title)
  if not title or title == "" then
      title = "Note"
  end
  
  local finalized_title = title
  local does_exist = check_if_exists_in_notes(title)

  if does_exist then
    local max_iterations = 100
    for i = 1, max_iterations do
      if i == max_iterations then 
        wada.sys.toast("Max copies reached!") 
        return title 
      end
      does_exist = false 
      if i == 1 then
        does_exist = check_if_exists_in_notes(title:gsub("_%d+", ""))
      else
        does_exist = check_if_exists_in_notes(title:gsub("_%d+", "") .. "_" .. i - 1)
      end

      if not does_exist then
        finalized_title = tostring(title:gsub("_%d+", "").. "_" .. i - 1)
        break
      end
    end
  end
  return tostring(finalized_title)
end

-- Safe local favorites loader preventing nil errors
local function load_local_favorites()
  local data = wada.fs.read("favorites.txt")
  if not data or type(data) ~= "string" then return {} end
  local favs = {}
  for name in string.gmatch(data, "[^\r\n]+") do
    favs[name] = true
  end
  return favs
end

function send_to_contacts(note)
 local w, h = get_board_size()
 wada.ui.clear()
 
 local contact_header = wada.ui.label("Send To Contacts", 0, 15, 14, C.accent or 0xFFFFFF, true)
 contact_header:width(w, "center")
 
 local contacts_list = wada.ui.list(10, 45, w - 20, h - 60)
 local cancel_btn= wada.ui.button("X", w - 45, 10, 30, 30, function() reset_ui() end) -- added color 10/29
 cancel_btn:bg(C.bad or 0xcc3333)
 local local_favs = load_local_favorites()
 local contacts = {}
 local seen_names = {}
 
 local total_count = wada.mesh.contact_count() or 0
 local limit = 250 -- Maximum limit allowed per SDK call
 local offset = 0
 
 -- Safety cap (e.g., 1000 nodes max) to prevent heap exhaustion on massive mesh lists
 local max_to_scan = math.min(total_count, 1000)
 if max_to_scan == 0 then max_to_scan = 150 end -- Fallback if contact_count isn't exposed
 
 -- Page through the entire contact book
 while offset < max_to_scan do
   local chunk = wada.mesh.contacts(offset, limit) or {}
   if #chunk == 0 then break end
   
   for _, contact in ipairs(chunk) do
   local name = contact.name
   local c_type = contact.type
   local c_flags = contact.flags or 0
   
   -- Exclude Type 2 (repeaters) and Type 3 (rooms)
   local is_infrastructure = (c_type == 2 or c_type == 3)
   
   if name and not is_infrastructure then
     if not seen_names[name] then
       seen_names[name] = true
       
       -- Native favorites bit check (Bit 0 of flags)
       local is_fav = (c_flags % 2) == 1
       
       table.insert(contacts, { name = name, is_fav = is_fav })
     end
   end
  end 
   
   offset = offset + limit
 end
 
 -- Sort favorites to the top, then alphabetically for the rest ( fav is not working)
 table.sort(contacts, function(a, b)
   if a.is_fav ~= b.is_fav then
     return a.is_fav
   else
     return a.name < b.name
   end
 end)
 
 if #contacts == 0 then
   contacts_list:add("No peer contacts found", function() end)
 else
   for i = 1, #contacts do
     local contact = contacts[i]
     local display_name = (contact.is_fav and "⭐ " or "") .. contact.name  -- This is not working to mark fav's 
     
     contacts_list:add(display_name, function()
       local file_content = wada.fs.read(note) or ""
       local note_text = note .. " - " .. tostring(file_content)
       wada.mesh.send_dm(contact.name, note_text)
       reset_ui()
       enter_note(note)
       wada.sys.toast("Sent to: " .. contact.name)
     end)
   end
 end
end

function enter_note(note)
  wada.ui.clear()
  local w, h = get_board_size()

  local last_number = string.match(note, "(%d+)%D*$")
  local start_pos = note:find("_", 1, true)
  local fixed_name = note
  local final_name

  if start_pos and last_number ~= nil then
    fixed_name = tostring(note:gsub("_" .. last_number, " (" .. tostring(last_number) .. ")"))
    final_name = fixed_name:gsub("_", " ")
  else
    final_name = fixed_name:gsub("_", " ")
  end

  local label = wada.ui.label(final_name, 0, 20, 30, C.text or 0xFFFFFF, true)
  label:width(w, "center")
  
  local content = wada.fs.read(note) or ""
  local text = wada.ui.label(tostring(content), 10, 60, 20, C.sub or 0xAAAAAA)
  text:width(w, "left")

  -- Navigation & Actions
  wada.ui.button("<-", 5, 5, 40, 40, function() reset_ui() end)
  wada.ui.button("Dup", w - 55, 5, 50, 40, function() duplicate_note(note) end)
  
  -- Bottom Action Row
  local edit_button = wada.ui.button("Edit", 10, h - 55, 50, 45, function() edit_note(note) end)
  if edit_button and edit_button.bg then edit_button:bg(0x3D3D3D) end

  local send_button = wada.ui.button("Send", 65, h - 55, w - 130, 45, function() send_to_contacts(note) end)
  if send_button and send_button.bg then send_button:bg(0x3D3D3D) end

  local trash_button = wada.ui.button("🔥", w - 60, h - 55, 50, 45, function() delete_note(note) end)
  if trash_button and trash_button.bg then trash_button:bg(0x3D3D3D) end
  if trash_button and trash_button.color then trash_button:color(C.accent or 0xFF5555) end
end

local dupe_cooldown = false

function duplicate_note(note)
  if dupe_cooldown then
    wada.sys.toast("Wait a bit to duplicate again!")
  else
    dupe_cooldown = true
    local data = wada.fs.read(note) or ""
    local name = tostring(more_names(note))
    wada.sys.toast(name)
    wada.fs.write(name, data)
    reset_ui()
    enter_note(name)
    wada.timer.after(1000, function() dupe_cooldown = false end)
  end
end

function create_note()
 input_string = ""
 wada.sys.toast("Note Name:")
 wada.ui.input("Note Name:", input_string, function(result_name)
   if not result_name or result_name == "nil" or result_name == "" then
     reset_ui()
     wada.sys.toast("Invalid Name!")
   else
     local name = tostring(more_names(result_name))
     local new_name = tostring(name:gsub(" ", "_"))
     
     wada.sys.toast("Note Content:")
     -- Pass 500 (or up to 2000) as the 4th argument here:
     wada.ui.input("Note:", input_string, function(result_note)
       local note_content = tostring(result_note)
       if not note_content or note_content == "nil" then
         reset_ui()
         wada.sys.toast("Invalid Note Content!")
       else
         wada.fs.write(new_name, note_content)
         wada.ui.clear()
         read_notes()
         enter_note(new_name)
       end
     end, 150) -- note input length set to 150 ( max send size?) max length is 500 (up to 2000?)
   end
 end, 63) -- Title can keep the shorter default length
end

function edit_note(note)
  local old_note = note
  local new_old_note = tostring(old_note:gsub("_", " "))
  local note_text = wada.fs.read(note) or ""
  
  wada.sys.toast("Edit Note Name:")
  wada.ui.input("Note Name:", new_old_note, function(result_name)
    if not result_name or result_name == "nil" or result_name == "" then
      reset_ui()
      wada.sys.toast("Invalid Name!") 
      enter_note(old_note)
    else
      local name = tostring(more_names(result_name))
      local new_name = tostring(name:gsub(" ", "_"))
      
      wada.sys.toast("Edit Note Content:")
      wada.ui.input("Note:", note_text, function(result_note)
        local updated_content = tostring(result_note)
        if updated_content == "nil" then
          reset_ui()
          wada.sys.toast("Invalid Edit!")
          enter_note(old_note)
        else
          delete_note(old_note)
          wada.fs.write(new_name, updated_content)
          enter_note(new_name)
        end
      end,150)
    end
  end,63)
end

function delete_note(note)
  wada.fs.remove(note)
  reset_ui()
end

function create_ui(w, h)
  local app_label = wada.ui.label("Notes", 0, 10, 16, C.text or '0xFFFFFF', true)
  -- app_label:width(w, "center")    -- commented out to match format of other apps 10/29
  
  local notes_list = wada.ui.list(10, 40, w - 20, h - 50)

  local file_count = wada.ui.label( tostring(#notes) .. " files",0,18,12,C.accent,true) -- added 10/29
  file_count:width(w, "center")  -- added 10/29

  for i = 1, #notes do
    local note = notes[i]
    local last_number = 0
    local start_pos
    if string.match(note, "(%d+)%D*$") ~= nil then
      last_number = string.match(note, "(%d+)%D*$")
      start_pos = note:find("_"..last_number, 1, true)
    end
    
    local fixed_name = note
    local final_name

    if start_pos then
      fixed_name = tostring(note:gsub("_" .. last_number, " (" .. tostring(last_number) .. ")"))
      final_name = fixed_name:gsub("_", " ")
    else
      final_name = fixed_name:gsub("_", " ")
    end

    notes_list:add(tostring(final_name), function()
      enter_note(tostring(note))
    end)
  end
  
  local add_btn= wada.ui.button("+", w - 50, h - 50, 40, 40, function() create_note() end)
  add_btn:bg(C.good or 0x22c55e)   -- added button color for better visibility 10/29
end

function read_notes()
  local note_list = wada.fs.list() or {}
  local names = {}

  for _, item in ipairs(note_list) do
    table.insert(names, item.name)
  end

  table.sort(names)
  notes = names
end

function app.on_open(w, h)
  read_notes()
  create_ui(w, h)
end

function app.on_tick()
end

return app
