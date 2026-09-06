--[[
    A Little Help  --  core bootstrap

    Files load alphabetically, so every ALH file carries a numeric load-order
    prefix: 00 Core, 10 Keybinds, 20 Main, 30 NPCMenu, 40 ContextMenu. This one
    is 00 and must load first. It owns:
      - the `ALH` namespace, preserved across hot-reloads
      - shared constants
      - ALH.log()
      - ALH.hookEvent()  -- attach a game-event handler once; on a hot-reload,
                            swap it in place instead of stacking a duplicate
      - ALH.devReload()  -- re-run every ALH lua file with no game restart
                            (-debug sessions only; bound to a button in the window)

    Hot-reload contract: every ALH file must be safe to execute more than once.
    Register handlers through ALH.hookEvent; guard other one-time work with a
    flag on ALH. See docs/ENGINEERING.md section 6.
]]

ALH = ALH or {}

ALH.ID           = "ALittleHelp"
ALH.VERSION      = "0.1.0"
ALH.KEYBIND_NAME = "ALH: Toggle helper menu"   -- used by ALH_10_Keybinds.lua

-- Handlers registered via ALH.hookEvent, keyed by a stable string so a reload
-- can replace the function without leaving the old one attached. Each entry is
-- { event = <name>, fn = <function> } so we detach from the right event even if
-- a reload moves a handler from one event to another.
ALH._eventHandlers = ALH._eventHandlers or {}

--- Print to console.txt with a consistent tag.
function ALH.log(msg)
    print("[A Little Help] " .. tostring(msg))
end

--- Attach `fn` to Events[eventName]. `key` identifies this hook; calling again
--- with the same key (a hot-reload re-running the file) detaches the previous
--- function first, so the event never accumulates duplicates.
--- @param eventName string  e.g. "OnKeyStartPressed"
--- @param key       string  stable id for this hook, e.g. "main.keyToggle"
--- @param fn        function
function ALH.hookEvent(eventName, key, fn)
    local event = Events[eventName]
    if not event then
        ALH.log("hookEvent: unknown event '" .. tostring(eventName) .. "'")
        return
    end

    local previous = ALH._eventHandlers[key]
    if previous and Events[previous.event] then
        Events[previous.event].Remove(previous.fn)
    end

    event.Add(fn)
    ALH._eventHandlers[key] = { event = eventName, fn = fn }
end

--- Re-run every loaded ALH lua file in place. -debug sessions only.
--- The helper window, if open, is closed and reopened so it picks up new code.
--- @return integer  number of files reloaded
function ALH.devReload()
    if not getDebug() then
        ALH.log("devReload ignored (start PZ with -debug to use it)")
        return 0
    end

    -- closeMenu remembers the window's geometry (ALH.windowRect); openMenu
    -- restores it, so the reloaded window comes back in the same place.
    local reopen = ALH.menu ~= nil
    if reopen then ALH.closeMenu() end

    local count = 0
    for i = 0, getLoadedLuaCount() - 1 do
        local path = getLoadedLua(i)
        if path and (string.find(path, "ALH_", 1, true) or string.find(path, ALH.ID, 1, true)) then
            reloadLuaFile(path)
            count = count + 1
        end
    end
    ALH.log("devReload: re-ran " .. count .. " file(s)")

    if reopen then ALH.openMenu() end

    local player = getPlayer()
    if player then
        player:setHaloNote("A Little Help reloaded (" .. count .. " files)")
    end
    return count
end

ALH.log("core loaded (v" .. ALH.VERSION .. ")")
