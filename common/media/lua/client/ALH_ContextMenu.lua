--[[
    A Little Help - world right-click menu.
    Adds a top-level "ALH NPC" entry with a small submenu. Behaves like any
    other vanilla right-click option.
]]

ALH_ContextMenu = ALH_ContextMenu or {}

function ALH_ContextMenu.onOpenMenu()
    ALH.toggleMenu()
end

function ALH_ContextMenu.onSpawnHere(worldobjects, player, square)
    ALH.spawnNPC(square)
end

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    if test then return true end
    if not ALH then return end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    -- Best guess at the square the player clicked on.
    local square = (worldobjects[1] and worldobjects[1]:getSquare())
        or player:getCurrentSquare()

    local parent = context:addOption("ALH NPC", worldobjects, nil)
    local sub    = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    sub:addOption("Spawn NPC Here", worldobjects, ALH_ContextMenu.onSpawnHere, player, square)
    sub:addOption("Open Helper Menu (G)", worldobjects, ALH_ContextMenu.onOpenMenu)

    local info = sub:addOption("Tracked NPCs: " .. tostring(#ALH.npcs), worldobjects, nil)
    info.notAvailable = true
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
