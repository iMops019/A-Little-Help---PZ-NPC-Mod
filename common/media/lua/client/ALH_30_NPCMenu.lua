--[[
    A Little Help  --  the helper window.

    A draggable, resizable ISCollapsableWindow: a list of tracked helpers with
    live status (distance, alive/dead) plus a row of buttons. In -debug sessions
    an extra "Reload ALH lua" button hot-reloads the mod (see ALH.devReload).

    View only: reads ALH.npcs, calls ALH.* actions. Holds no domain state. The
    list is refreshed structurally by refreshList() (rows added/removed) and its
    text is updated live each frame by updateRows() from prerender().
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
    o:setWantKeyEvents(true)   -- receive onKeyRelease / isKeyConsumed (ESC to close)
    return o
end

-- ESC closes the window. isKeyConsumed then stops the same keypress reaching the
-- pause-menu handler (ToggleEscapeMenu, which runs on key release), so the first
-- ESC closes this window and a second ESC opens the pause menu - same as the
-- vanilla build / craft / map windows.
function ALH_NPCMenu:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then
        self:close()
    end
end

function ALH_NPCMenu:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
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

    -- List box. Reserve space for the button rows below it (a 3rd dev row
    -- exists only in -debug sessions).
    local buttonRows = getDebug() and 3 or 2
    local reserved   = (BTN_H + PAD) * buttonRows
    local listH      = math.max(60, self.height - y - PAD - reserved)

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
    self.spawnBtn:setTooltip("Spawn a tamed-zombie helper at your feet.")
    self:addChild(self.spawnBtn)

    self.removeBtn = ISButton:new(x + halfW + PAD, y, halfW, BTN_H, "Remove", self, ALH_NPCMenu.onButton)
    self.removeBtn.internal = "REMOVE"
    self.removeBtn:initialise()
    self.removeBtn:instantiate()
    self.removeBtn:setTooltip("Remove the selected helper from the world.")
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

    -- Row 3 (dev only): hot-reload every ALH lua file, no game restart.
    if getDebug() then
        y = y + BTN_H + PAD
        self.reloadBtn = ISButton:new(x, y, w, BTN_H, "Reload ALH lua (dev)", self, ALH_NPCMenu.onButton)
        self.reloadBtn.internal = "DEVRELOAD"
        self.reloadBtn:initialise()
        self.reloadBtn:instantiate()
        self.reloadBtn:setTooltip("Re-runs every A Little Help lua file. Run deploy.ps1 first.")
        self:addChild(self.reloadBtn)
    end
end

--- One row's live status line.
function ALH_NPCMenu:rowText(rec)
    local z = rec.obj
    if not z or z:isDead() then
        return (rec.name or "Helper") .. "  --  dead"
    end
    local player = getPlayer()
    if player then
        return string.format("%s  --  %d tiles", rec.name or "Helper",
            math.floor(player:DistTo(z)))
    end
    return rec.name or "Helper"
end

--- Rebuild the list box from ALH.npcs (call when the roster changes).
function ALH_NPCMenu:refreshList()
    if not self.npcList then return end

    local prev = self.npcList.selected
    self.npcList:clear()

    if #ALH.npcs == 0 then
        self.npcList:addItem("(no helpers - press Spawn NPC)", nil)
        self.npcList.selected = -1
        return
    end

    for _, rec in ipairs(ALH.npcs) do
        self.npcList:addItem(self:rowText(rec), rec)
    end

    if prev >= 1 and prev <= #ALH.npcs then
        self.npcList.selected = prev
    end
end

--- Refresh each row's text from live data without rebuilding the list, so
--- selection and scroll position are kept.
function ALH_NPCMenu:updateRows()
    if not self.npcList then return end
    for _, row in ipairs(self.npcList.items) do
        if row.item then   -- skip the "(no helpers)" placeholder row
            row.text = self:rowText(row.item)
        end
    end
end

function ALH_NPCMenu:prerender()
    ISCollapsableWindow.prerender(self)
    local now = getTimestampMs()
    if not self._liveUpdateAt or now >= self._liveUpdateAt then
        self._liveUpdateAt = now + 250   -- 4x/sec is plenty for a distance readout
        self:updateRows()
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

    elseif id == "DEVRELOAD" then
        ALH.devReload()   -- closes and reopens this window with fresh code
    end
end

-- Close via our own button, the title-bar X, or a second G press all route here.
function ALH_NPCMenu:close()
    ALH.rememberWindowRect(self)   -- so the next open reopens where this was
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if ALH.menu == self then
        ALH.menu = nil
    end
    ALH.log("menu closed")
end
