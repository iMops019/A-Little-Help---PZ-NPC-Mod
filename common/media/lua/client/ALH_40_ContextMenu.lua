--[[
    A Little Help  --  world right-click menu.

    Plain vanilla-style context options:
      - top-level "ALH NPC"  -> Spawn NPC Here / Open Helper Menu, plus (when a
        helper is selected) "Send <name> here" and, on a tree, chop it
      - top-level "<name> (helper)" for each helper on the clicked tile
        -> Come here / Follow me|Stay / Give axe|Chop nearest tree / Select /
           Send away
]]

ALH_ContextMenu = ALH_ContextMenu or {}

-- Call an ALH entry point, tolerating a nil - a partial hot-reload can leave the
-- namespace mid-rebuild. Logs instead of crashing the context callback.
local function call(name, ...)
    local fn = ALH[name]
    if type(fn) == "function" then
        fn(...)
    else
        ALH.log("context: ALH." .. name .. " not ready - reload or restart")
    end
end

function ALH_ContextMenu.onSpawnHere(worldobjects, player, square) call("spawnNPC", square) end
function ALH_ContextMenu.onOpenMenu()                              call("openMenu") end
function ALH_ContextMenu.onSelectHelper(worldobjects, rec)         call("selectNPC", rec) end
function ALH_ContextMenu.onComeHere(worldobjects, rec)             call("comeHere", rec) end
function ALH_ContextMenu.onFollow(worldobjects, rec)               call("follow", rec) end
function ALH_ContextMenu.onStay(worldobjects, rec)                 call("stay", rec) end
function ALH_ContextMenu.onGiveAxe(worldobjects, rec)              call("giveAxe", rec) end
function ALH_ContextMenu.onChopTree(worldobjects, rec, tree)       call("chopTree", rec, tree) end
function ALH_ContextMenu.onChopNearest(worldobjects, rec)          call("chopNearestTree", rec) end
function ALH_ContextMenu.onSendAway(worldobjects, rec)             call("removeNPC", rec) end

function ALH_ContextMenu.onGoHere(worldobjects, player, square)
    if ALH.selected then call("goTo", ALH.selected, square) end
end

--- Living helpers standing on (or right next to) `square`. ~1.5 tiles, so a
--- click that lands one tile off the helper still finds it.
local function helpersAt(square)
    local found = {}
    if not square then return found end
    local cx, cy, cz = square:getX() + 0.5, square:getY() + 0.5, square:getZ()
    for _, rec in ipairs(ALH.npcs) do
        local z   = rec.obj
        local zsq = z and z:getSquare()
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

    local parent = context:addOption("ALH NPC", worldobjects, nil)
    local sub    = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    sub:addOption("Spawn NPC Here", worldobjects, ALH_ContextMenu.onSpawnHere, player, square)
    sub:addOption("Open Helper Menu (G)", worldobjects, ALH_ContextMenu.onOpenMenu)

    -- Commands for the selected helper aimed at the clicked tile.
    local sel = ALH.selected
    if sel and sel.obj and not sel.obj:isDead() then
        local name = sel.name or "helper"
        local tree = square and square:HasTree() and square:getTree()
        if tree and sel.armed then
            sub:addOption("Send " .. name .. " to chop this tree",
                worldobjects, ALH_ContextMenu.onChopTree, sel, tree)
        elseif tree then
            sub:addOption(name .. " needs an axe to chop", worldobjects, nil).notAvailable = true
        end
        sub:addOption("Send " .. name .. " here",
            worldobjects, ALH_ContextMenu.onGoHere, player, square)
    end

    sub:addOption("Helpers: " .. tostring(#ALH.npcs), worldobjects, nil).notAvailable = true

    -- A submenu per helper standing here.
    for _, rec in ipairs(helpersAt(square)) do
        local opt  = context:addOption((rec.name or "Helper") .. "  (helper)", worldobjects, nil)
        local hsub = ISContextMenu:getNew(context)
        context:addSubMenu(opt, hsub)

        hsub:addOption("Come here", worldobjects, ALH_ContextMenu.onComeHere, rec)

        if rec.order == "follow" then
            hsub:addOption("Stay", worldobjects, ALH_ContextMenu.onStay, rec)
        else
            hsub:addOption("Follow me", worldobjects, ALH_ContextMenu.onFollow, rec)
        end

        if rec.armed then
            hsub:addOption("Chop nearest tree", worldobjects, ALH_ContextMenu.onChopNearest, rec)
        else
            hsub:addOption("Give axe", worldobjects, ALH_ContextMenu.onGiveAxe, rec)
        end

        hsub:addOption("Select", worldobjects, ALH_ContextMenu.onSelectHelper, rec)
        hsub:addOption("Send away", worldobjects, ALH_ContextMenu.onSendAway, rec)
    end
end

ALH.hookEvent("OnFillWorldObjectContextMenu", "contextMenu.fill", onFillWorldObjectContextMenu)
