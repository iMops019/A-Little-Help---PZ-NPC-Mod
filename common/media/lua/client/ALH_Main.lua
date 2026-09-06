--[[
    A Little Help - core namespace, "spawn" stub, and key handling.
    Build 42, client-side only for now.
]]

ALH = ALH or {}
ALH.VERSION = "0.1.0"
ALH.KEYBIND_NAME = "ALH: Toggle helper menu"

-- The list the UI shows. Nothing real lives here yet - Spawn NPC just
-- appends a placeholder so the window and list box have something to display.
ALH.npcs = ALH.npcs or {}

function ALH.log(msg)
    print("[A Little Help] " .. tostring(msg))
end

--- Add a placeholder "NPC". No actor is created in the world yet.
--- @param square IsoGridSquare|nil  where the stub should be pinned (defaults to the player's square)
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

    ALH.log(string.format("stubbed '%s' at %d,%d,%d  (no actor spawned - WIP)",
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

--- Toggle the helper window open/closed.
function ALH.toggleMenu()
    if not getPlayer() then return end

    if ALH.menu then
        ALH.menu:close()   -- ALH_NPCMenu:close() sets ALH.menu back to nil
        return
    end

    local w, h = 340, 400
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2
    ALH.menu = ALH_NPCMenu:new(x, y, w, h)
    ALH.menu:initialise()
    ALH.menu:addToUIManager()
    ALH.menu:refreshList()
    ALH.log("menu opened")
end

-- Key handling. Prefer the rebindable keybind; fall back to a hard G if the
-- keybind table wasn't available at load time for some reason.
local function ALH_onKeyPressed(key)
    if not getPlayer() then return end

    local bound = getCore():getKey(ALH.KEYBIND_NAME)
    local haveBound = bound ~= nil and bound ~= 0

    if (haveBound and key == bound) or (not haveBound and key == Keyboard.KEY_G) then
        ALH.toggleMenu()
    end
end

Events.OnKeyPressed.Add(ALH_onKeyPressed)

ALH.log("loaded v" .. ALH.VERSION)
