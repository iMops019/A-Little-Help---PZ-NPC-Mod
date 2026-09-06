--[[
    A Little Help - key bindings
    Shows up in-game under Options > Key Bindings > "A Little Help".
    Default key is G. Rebind it there if it clashes with something you use.
]]

if keyBinding then
    -- A row with only "value" and no "key" renders as a section header.
    table.insert(keyBinding, { value = "[A Little Help]" })
    table.insert(keyBinding, { value = "ALH: Toggle helper menu", key = Keyboard.KEY_G })
end
