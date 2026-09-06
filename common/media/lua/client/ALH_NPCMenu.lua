--[[
    A Little Help - the helper window.
    A draggable, resizable ISCollapsableWindow with a Tracked NPCs list and a
    row of buttons. None of the buttons do anything in the world yet.
]]

require "ISUI/ISCollapsableWindow"

ALH_NPCMenu = ISCollapsableWindow:derive("ALH_NPCMenu")

local PAD    = 10
local BTN_H  = 25
local ROW_H  = 22

function ALH_NPCMenu:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title          = "A Little Help"
    o.resizable       = true
    o.minimumWidth    = 280
    o.minimumHeight   = 260
    o.backgroundColor = { r = 0.06, g = 0.07, b = 0.09, a = 0.95 }
    o.borderColor     = { r = 0.40, g = 0.65, b = 0.92, a = 1.0 }
    return o
end

function ALH_NPCMenu:createChildren()
    ISCollapsableWindow.createChildren(self)

    local top = self:titleBarHeight()
    local x   = PAD
    local w   = self.width - PAD * 2
    local y   = top + PAD

    -- Section header
    -- ISLabel:new(x, y, height, text, r, g, b, a, font, bLeftAligned)
    self.header = ISLabel:new(x, y, 18, "Tracked NPCs", 0.85, 0.92, 1.0, 1.0, UIFont.Medium, true)
    self.header:initialise()
    self:addChild(self.header)
    y = y + 24

    -- List box: two rows of buttons live below it, so reserve that space.
    local reserved  = (BTN_H + PAD) * 2
    local listH     = math.max(60, self.height - y - PAD - reserved)

    self.npcList = ISScrollingListBox:new(x, y, w, listH)
    self.npcList:initialise()
    self.npcList:instantiate()
    self.npcList.itemheight       = ROW_H
    self.npcList.font             = UIFont.Small
    self.npcList.drawBorder       = true
    self.npcList.selected         = -1
    self.npcList.backgroundColor  = { r = 0.0, g = 0.0, b = 0.0, a = 0.40 }
    self.npcList.borderColor      = { r = 0.40, g = 0.50, b = 0.62, a = 0.80 }
    self:addChild(self.npcList)
    y = y + listH + PAD

    local halfW = (w - PAD) / 2

    -- Row 1: Spawn | Remove
    self.spawnBtn = ISButton:new(x, y, halfW, BTN_H, "Spawn NPC", self, ALH_NPCMenu.onButton)
    self.spawnBtn.internal = "SPAWN"
    self.spawnBtn:initialise()
    self.spawnBtn:instantiate()
    self.spawnBtn:enableAcceptColor()
    self.spawnBtn:setTooltip("Adds a placeholder NPC to the list. Nothing spawns in the world yet.")
    self:addChild(self.spawnBtn)

    self.removeBtn = ISButton:new(x + halfW + PAD, y, halfW, BTN_H, "Remove", self, ALH_NPCMenu.onButton)
    self.removeBtn.internal = "REMOVE"
    self.removeBtn:initialise()
    self.removeBtn:instantiate()
    self.removeBtn:setTooltip("Removes the selected NPC from the list.")
    self:addChild(self.removeBtn)
    y = y + BTN_H + PAD

    -- Row 2: Refresh | Close
    self.refreshBtn = ISButton:new(x, y, halfW, BTN_H, "Refresh", self, ALH_NPCMenu.onButton)
    self.refreshBtn.internal = "REFRESH"
    self.refreshBtn:initialise()
    self.refreshBtn:instantiate()
    self:addChild(self.refreshBtn)

    self.closeBtn2 = ISButton:new(x + halfW + PAD, y, halfW, BTN_H, "Close", self, ALH_NPCMenu.onButton)
    self.closeBtn2.internal = "CLOSE"
    self.closeBtn2:initialise()
    self.closeBtn2:instantiate()
    self.closeBtn2:enableCancelColor()
    self:addChild(self.closeBtn2)
end

--- Rebuild the list box from ALH.npcs.
function ALH_NPCMenu:refreshList()
    if not self.npcList then return end

    local prev = self.npcList.selected
    self.npcList:clear()

    if #ALH.npcs == 0 then
        self.npcList:addItem("(no NPCs yet - press Spawn NPC)", nil)
        self.npcList.selected = -1
        return
    end

    for i, npc in ipairs(ALH.npcs) do
        local label = string.format("%s    [%d, %d, %d]",
            npc.name or ("NPC " .. i), npc.x, npc.y, npc.z)
        self.npcList:addItem(label, npc)
    end

    if prev >= 1 and prev <= #ALH.npcs then
        self.npcList.selected = prev
    end
end

function ALH_NPCMenu:getSelectedNPC()
    local row = self.npcList and self.npcList.items[self.npcList.selected]
    return row and row.item or nil
end

function ALH_NPCMenu:onButton(button)
    local id = button.internal

    if id == "SPAWN" then
        ALH.spawnNPC()

    elseif id == "REMOVE" then
        local npc = self:getSelectedNPC()
        if npc then ALH.removeNPC(npc) end

    elseif id == "REFRESH" then
        self:refreshList()

    elseif id == "CLOSE" then
        self:close()
    end
end

-- Close via our own button, the title-bar X, or a second G press all route here.
function ALH_NPCMenu:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if ALH.menu == self then
        ALH.menu = nil
    end
    ALH.log("menu closed")
end
