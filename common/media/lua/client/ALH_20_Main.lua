--[[
    A Little Help  --  helper-window control + keybind handling.

    The `ALH` namespace, constants, ALH.log and ALH.hookEvent live in
    ALH_00_Core.lua. This file owns opening/closing the window, the NPC list
    model, and the G keypress.
]]

require "ISUI/ISLayoutManager"

local WINDOW_W, WINDOW_H = 340, 400
local LAYOUT_NAME        = "ALH_helper"   -- ISLayoutManager key (global namespace)

-- Tracked NPCs. Each record: { id, name, desc, obj, x, y, z }
--   desc = <SurvivorDesc>   (name / appearance data)
--   obj  = the live IsoZombie actor, or nil
--
-- Foundation (see docs/ARCHITECTURE.md "Spawning"): IsoSurvivor is dead code in
-- B42, so a helper is a *tamed zombie* - lore: "kinda cured" infected. The horde
-- ignores it (still reads as infected), it can't fully talk, it shambles. We
-- defang it (setNoTeeth) and clear its target every tick so it won't chase.
ALH.npcs = ALH.npcs or {}

-- Marker set on a helper zombie's ModData - "this one is ours", for checks that
-- only have the zombie in hand (e.g. a context menu on it later).
local TAMED_FLAG = "alhTamed"

-- Remembered window geometry { x, y, w, h }, or nil for a centred default.
-- Updated every time the window closes, so a G-toggle reopens where you left it.
-- ISLayoutManager (below) seeds it from disk on the first open of a session and
-- writes it back on game save, so it also survives a restart.
ALH.windowRect = ALH.windowRect or nil

--- Spawn a tamed-zombie helper at `square` and record it.
---
--- B-1 is the minimum: create the zombie, mark it, take its teeth, and let the
--- per-tick hook keep its target clear. No appearance change, no follow yet -
--- the point is to see it stand there peacefully.
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

    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    ALH.log(string.format("spawnNPC: creating tamed zombie at %d,%d,%d", sx, sy, sz))

    local vzm = getVirtualZombieManager()
    local z = vzm and vzm:createRealZombieNow(sx + 0.5, sy + 0.5, sz)
    if not z then
        ALH.log("spawnNPC: createRealZombieNow returned nil")
        return nil
    end
    if not z:getSquare() then
        ALH.log("spawnNPC: zombie has no square (bad tile?), discarding")
        z:removeFromWorld()
        return nil
    end

    -- Identity (name now; appearance is B-2).
    local desc = SurvivorFactory.CreateSurvivor()
    SurvivorFactory.randomName(desc)
    local fore, sur = desc:getForename(), desc:getSurname()
    local name = (fore and sur) and (fore .. " " .. sur) or "Helper"

    -- Minimal tame.
    z:getModData()[TAMED_FLAG] = true
    z:setNoTeeth(true)
    z:setTarget(nil)

    local rec = {
        id   = "alh_npc_" .. (#ALH.npcs + 1),
        name = name,
        desc = desc,
        obj  = z,
        x = sx, y = sy, z = sz,
    }
    table.insert(ALH.npcs, rec)

    ALH.log(string.format("spawnNPC: tamed zombie '%s' spawned at %d,%d,%d", name, sx, sy, sz))
    if player then player:setHaloNote("A Little Help: " .. name .. " joined") end
    if ALH.menu then ALH.menu:refreshList() end
    return rec
end

--- Remove an NPC: take its actor out of the world, then drop the record.
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

-- Keep tamed zombies from chasing anything. Driven off OnTick (once per tick)
-- over our small roster - not OnZombieUpdate, which would fire for every zombie
-- in the world and allocate a ModData table for each.
local function onTick()
    for _, rec in ipairs(ALH.npcs) do
        local z = rec.obj
        if z and not z:isDead() and z:getTarget() then
            z:setTarget(nil)
        end
    end
end
ALH.hookEvent("OnTick", "spawn.tameZombies", onTick)

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
