--[[
    A Little Help  --  helper-window control + keybind handling.

    The `ALH` namespace, constants, ALH.log and ALH.hookEvent live in
    ALH_00_Core.lua. This file owns opening/closing the window, the NPC list
    model, and the G keypress.
]]

require "ISUI/ISLayoutManager"

local WINDOW_W, WINDOW_H = 340, 400
local LAYOUT_NAME        = "ALH_helper"   -- ISLayoutManager key (global namespace)

-- Tracked NPCs. Each record:
--   { id, name, desc = <SurvivorDesc>, obj = <IsoSurvivor>, x, y, z }
-- `desc` is kept so a future version can respawn or re-roll the same NPC without
-- touching the roster model (see the design notes / ENGINEERING.md).
ALH.npcs = ALH.npcs or {}

local HELLO_LINE = "Hello, I'm ready to work!"

-- Remembered window geometry { x, y, w, h }, or nil for a centred default.
-- Updated every time the window closes, so a G-toggle reopens where you left it.
-- ISLayoutManager (below) seeds it from disk on the first open of a session and
-- writes it back on game save, so it also survives a restart.
ALH.windowRect = ALH.windowRect or nil

--- Spawn a real IsoSurvivor at `square` and add a record for it.
---
--- B-1 is exploratory: SurvivorFactory.InstansiateInCell is never called by the
--- base game, so this logs each step to console.txt. InstansiateInCell only
--- constructs the survivor - it does not add it to the world - so we do that and
--- pin its position afterwards.
---
--- @param square IsoGridSquare|nil  target tile (default: the player's)
--- @return table|nil  the record that was added, or nil on failure
function ALH.spawnNPC(square)
    local player = getPlayer()
    square = square or (player and player:getCurrentSquare()) or nil
    if not square then
        ALH.log("spawnNPC: no target square")
        return nil
    end

    local cell = getCell()
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    ALH.log(string.format("spawnNPC: attempting spawn at %d,%d,%d", sx, sy, sz))

    local desc = SurvivorFactory.CreateSurvivor()
    SurvivorFactory.randomName(desc)

    local npc = SurvivorFactory.InstansiateInCell(desc, cell, sx, sy, sz)
    if not npc then
        ALH.log("spawnNPC: InstansiateInCell returned nil")
        return nil
    end

    -- The constructor can bail mid-build on a bad tile / id clash and hand back a
    -- half-built object (this is what the animal spawners guard against).
    if not npc:getSquare() then
        ALH.log("spawnNPC: half-built survivor (no square), discarding")
        npc:removeFromWorld()
        return nil
    end

    -- Put it in the world so it renders and ticks, then pin it to the tile.
    cell:addMovingObject(npc)
    npc:setX(sx + 0.5)
    npc:setY(sy + 0.5)
    npc:setZ(sz)
    npc:setCurrent(square)

    npc:Say(HELLO_LINE)

    local n = #ALH.npcs + 1
    local fore, sur = desc:getForename(), desc:getSurname()
    local name = (fore and sur) and (fore .. " " .. sur) or ("Survivor #" .. n)

    local rec = {
        id   = "alh_npc_" .. n,
        name = name,
        desc = desc,
        obj  = npc,
        x = sx, y = sy, z = sz,
    }
    table.insert(ALH.npcs, rec)

    ALH.log(string.format("spawnNPC: spawned '%s' at %d,%d,%d", name, sx, sy, sz))
    if player then player:setHaloNote("A Little Help: spawned " .. name) end
    if ALH.menu then ALH.menu:refreshList() end
    return rec
end

--- Remove an NPC: take its actor out of the world, then drop the record.
--- (IsoSurvivor:Despawn() only nils the desc link, so we use removeFromWorld.)
function ALH.removeNPC(rec)
    if rec.obj then
        rec.obj:removeFromWorld()
    end
    for i = #ALH.npcs, 1, -1 do
        if ALH.npcs[i] == rec then
            table.remove(ALH.npcs, i)
        end
    end
    ALH.log("removeNPC: removed " .. tostring(rec.name))
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
