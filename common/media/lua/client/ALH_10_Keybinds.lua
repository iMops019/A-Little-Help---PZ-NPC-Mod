--[[
    A Little Help  --  key bindings

    Adds rows to Options > Key Bindings > "[A Little Help]".  Default key: G.
    Changing these needs a real game restart (the keybind table is read at
    startup), so this file is not part of the hot-reload story - but it is still
    written to be safe to re-run.
]]

--- Insert one keyBinding row, unless a row with this value already exists
--- (a hot-reload, or the game re-scanning, would otherwise stack duplicates).
local function ensureBinding(value, key)
    for _, row in ipairs(keyBinding) do
        if row.value == value then return end
    end
    table.insert(keyBinding, { value = value, key = key })
end

if keyBinding then
    ensureBinding("[A Little Help]", nil)              -- section header (no key)
    ensureBinding(ALH.KEYBIND_NAME, Keyboard.KEY_G)
end
