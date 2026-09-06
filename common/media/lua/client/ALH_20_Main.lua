--[[
    A Little Help  --  helper-window control + keybind handling.

    The `ALH` namespace, constants, ALH.log and ALH.hookEvent live in
    ALH_00_Core.lua. This file owns opening/closing the window, the NPC list
    model, and the G keypress.
]]

require "ISUI/ISLayoutManager"

local WINDOW_W, WINDOW_H = 340, 400
local LAYOUT_NAME        = "ALH_helper"   -- ISLayoutManager key (global namespace)

-- Tracked NPCs. Placeholders in this version: Spawn NPC appends a stub so the
-- window and list box have something to show. Real actors arrive in v0.2.
ALH.npcs = ALH.npcs or {}

-- Remembered window geometry { x, y, w, h }, or nil for a centred default.
-- Updated every time the window closes, so a G-toggle reopens where you left it.
-- ISLayoutManager (below) seeds it from disk on the first open of a session and
-- writes it back on game save, so it also survives a restart.
ALH.windowRect = ALH.windowRect or nil

--- Append a placeholder NPC. No world actor is created yet.
--- @param square IsoGridSquare|nil  tile to pin it to (default: the player's)
--- @return table  the stub that was added
function ALH.spawnNPC(square)
    local player = getPlayer()
    square = square or (player and player:getCurrentSquare()) or nil

    local n = #ALH.npcs + 1
    local stub = {
        id   = "alh_npc_" .. n,
        name = "Survivor #" .. n,
        x    = square and square:getX() or 0,
        y    = square and square:getY() or 0,
        z    = square and square:getZ() or 0,
    }
    table.insert(ALH.npcs, stub)

    ALH.log(string.format("stubbed '%s' at %d,%d,%d (no actor spawned - WIP)",
        stub.name, stub.x, stub.y, stub.z))
    if player then
        player:setHaloNote("A Little Help: stubbed " .. stub.name)
    end

    if ALH.menu then ALH.menu:refreshList() end
    return stub
end

--- Drop a stub from the list.
function ALH.removeNPC(stub)
    for i = #ALH.npcs, 1, -1 do
        if ALH.npcs[i] == stub then
            table.remove(ALH.npcs, i)
        end
    end
    if ALH.menu then ALH.menu:refreshList() end
end

--- Open the helper window, unless it is already open. Restores its last
--- position/size from ALH.windowRect (or centres it if there isn't one yet).
function ALH.openMenu()
    if ALH.menu then return end
    if not getPlayer() then return end

    local r = ALH.windowRect
    local w = (r and r.w) or WINDOW_W
    local h = (r and r.h) or WINDOW_H
    local x = (r and r.x) or (getCore():getScreenWidth()  - w) / 2
    local y = (r and r.y) or (getCore():getScreenHeight() - h) / 2

    ALH.menu = ALH_NPCMenu:new(x, y, w, h)
    ALH.menu:initialise()
    ALH.menu:addToUIManager()

    -- Persist geometry across game sessions (Zomboid/Lua/layout.ini). Registering
    -- also restores the on-disk layout right now - what we want on the first open
    -- of a session. On later opens ALH.windowRect is fresher, so re-apply it.
    ISLayoutManager.RegisterWindow(LAYOUT_NAME, ALH_NPCMenu, ALH.menu)
    if r then
        ALH.menu:setX(r.x)
        ALH.menu:setY(r.y)
    end

    ALH.menu:refreshList()
    ALH.log("menu opened")
end

--- Snapshot a window's geometry into ALH.windowRect. The window calls this as it
--- tears down, so every close path - G, the Close button, the title-bar X - is
--- covered from one place.
function ALH.rememberWindowRect(window)
    window = window or ALH.menu
    if not window then return end
    if window.isCollapsed then return end   -- height would be the title bar only
    ALH.windowRect = {
        x = window:getX(),     y = window:getY(),
        w = window:getWidth(), h = window:getHeight(),
    }
end

--- Close the helper window, if it is open. ALH_NPCMenu:close() remembers the
--- position and clears ALH.menu.
function ALH.closeMenu()
    if ALH.menu then ALH.menu:close() end
end

--- Toggle the helper window.
function ALH.toggleMenu()
    if ALH.menu then ALH.closeMenu() else ALH.openMenu() end
end

-- G (rebindable) toggles the window.
--
-- We use OnKeyStartPressed, not OnKeyPressed: the engine skips OnKeyStartPressed
-- when a text field has keyboard focus (UIManager.onKeyPress consumes the key
-- first), so typing in chat, a rename dialog, the map search or the debug
-- console won't pop the menu. OnKeyPressed fires regardless.
local function onKeyStartPressed(key)
    if not getPlayer() then return end

    local bound = getCore():getKey(ALH.KEYBIND_NAME)
    local haveBound = bound ~= nil and bound ~= 0

    if (haveBound and key == bound) or (not haveBound and key == Keyboard.KEY_G) then
        ALH.toggleMenu()
    end
end

ALH.hookEvent("OnKeyStartPressed", "main.keyToggle", onKeyStartPressed)

ALH.log("main ready")
