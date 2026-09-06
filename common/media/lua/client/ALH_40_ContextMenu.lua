--[[
    A Little Help  --  world right-click menu.

    Two things, both plain vanilla-style context options:
      - top-level "ALH NPC"  -> Spawn NPC Here / Open Helper Menu
      - top-level "<name> (helper)" for each helper on the clicked tile
        -> Come here / Select / Send away. The spine commands hang off.
]]

ALH_ContextMenu = ALH_ContextMenu or {}

function ALH_ContextMenu.onSpawnHere(worldobjects, player, square)
    ALH.spawnNPC(square)
end

function ALH_ContextMenu.onOpenMenu()
    ALH.openMenu()
end

function ALH_ContextMenu.onSelectHelper(worldobjects, rec)
    ALH.selectNPC(rec)
end

function ALH_ContextMenu.onComeHere(worldobjects, rec)
    ALH.comeHere(rec)
end

function ALH_ContextMenu.onSendAway(worldobjects, rec)
    ALH.removeNPC(rec)
end

--- Living helpers standing on (or right next to) `square`. ~1.5 tiles, so a
--- click that lands one tile off the helper still finds it.
local function helpersAt(square)
    local found = {}
    if not square then return found end
    local cx, cy, cz = square:getX() + 0.5, square:getY() + 0.5, square:getZ()
    for _, rec in ipairs(ALH.npcs) do
        local z    = rec.obj
        local zsq  = z and z:getSquare()
        if zsq and not z:isDead() and zsq:getZ() == cz and z:DistToSquared(cx, cy) < 2.25 then
            table.insert(found, rec)
        end
    end
    return found
end

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    if test then return true end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    -- Best guess at the tile the player clicked on.
    local square = (worldobjects[1] and worldobjects[1]:getSquare())
        or player:getCurrentSquare()

    -- "ALH NPC" - spawn / open, always available.
    local parent = context:addOption("ALH NPC", worldobjects, nil)
    local sub    = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    sub:addOption("Spawn NPC Here", worldobjects, ALH_ContextMenu.onSpawnHere, player, square)
    sub:addOption("Open Helper Menu (G)", worldobjects, ALH_ContextMenu.onOpenMenu)

    local info = sub:addOption("Helpers: " .. tostring(#ALH.npcs), worldobjects, nil)
    info.notAvailable = true

    -- A submenu per helper standing here.
    for _, rec in ipairs(helpersAt(square)) do
        local opt  = context:addOption((rec.name or "Helper") .. "  (helper)", worldobjects, nil)
        local hsub = ISContextMenu:getNew(context)
        context:addSubMenu(opt, hsub)
        hsub:addOption("Come here", worldobjects, ALH_ContextMenu.onComeHere, rec)
        hsub:addOption("Select", worldobjects, ALH_ContextMenu.onSelectHelper, rec)
        hsub:addOption("Send away", worldobjects, ALH_ContextMenu.onSendAway, rec)
    end
end

ALH.hookEvent("OnFillWorldObjectContextMenu", "contextMenu.fill", onFillWorldObjectContextMenu)
