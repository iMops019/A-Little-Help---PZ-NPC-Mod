--[[
    A Little Help  --  "Chop a tree" targeting cursor.

    Right-click a helper -> "Chop a tree" puts the player in a cursor mode
    (getCell():setDrag) where hovered trees highlight; left-click a tree and the
    helper is ordered to chop it, then the cursor exits.

    A near-copy of the vanilla ISChopTreeCursor, retargeted from the player to a
    helper record and made one-shot.
]]

require "BuildingObjects/ISBuildingObject"

ALH_ChopCursor = ISBuildingObject:derive("ALH_ChopCursor")

function ALH_ChopCursor:new(character, rec)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o:setSprite("")
    o:setNorthSprite("")
    o.character      = character
    o.player         = character:getPlayerNum()
    o.rec            = rec
    o.noNeedHammer   = true
    o.skipBuildAction = true
    return o
end

function ALH_ChopCursor:isValid(square)
    return square ~= nil and square:HasTree()
end

function ALH_ChopCursor:render(x, y, z, square)
    local hc = getCore():getBadHighlitedColor()
    if self:isValid(square) then
        hc = getCore():getGoodHighlitedColor()
        square:getTree():setHighlighted(true)
    end
    self:getFloorCursorSprite():RenderGhostTileColor(x, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
end

-- The helper walks itself (tickHelper) - don't march the player to the tree.
function ALH_ChopCursor:walkTo(x, y, z)
    return true
end

function ALH_ChopCursor:create(x, y, z, north, sprite)
    local square = getWorld():getCell():getGridSquare(x, y, z)
    if square and square:HasTree() and self.rec and self.rec.obj then
        ALH.chopTree(self.rec, square:getTree())
    end
    getCell():setDrag(nil, self.player)   -- one-shot: leave cursor mode
end

--- Enter cursor mode for `rec`, driven by `player`.
function ALH_ChopCursor.begin(rec, player)
    if not player or not rec then return end
    getCell():setDrag(ALH_ChopCursor:new(player, rec), player:getPlayerNum())
end
