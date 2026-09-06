# Roadmap

Rough order of attack. Nothing here is a commitment - it's a plan to argue with.

## 0.1.x - polish the shell (current)

- [ ] Guard `G` so it does nothing while the chat box / any text entry is focused.
- [ ] `poster.png` (128x128 or 256x256) so the mod looks finished in the list.
- [ ] Persist `ALH.npcs` across save/reload via `ModData`
      (`getPlayer():getModData()` or a global `ModData.getOrCreate`).
- [ ] Selecting a row in the list box shows its details / a "teleport to" button.

## 0.2.0 - a body in the world

Get *something* to actually appear when "Spawn NPC" is pressed.

- [ ] Spawn an `IsoZombie` or survivor-model actor at the target square as a
      first proof of life (even if it just stands there).
- [ ] Track the real object on the stub: `stub.obj = <IsoGameCharacter>`.
- [ ] `Remove` deletes the world object too (`obj:removeFromWorld()` /
      `obj:removeFromSquare()`).
- [ ] Make it non-hostile: faction / `setInFaction` or the B42 NPC hooks, so
      zombies and the player don't attack it on sight.
- [ ] Handle chunk unload/reload - re-resolve `stub.obj` or despawn cleanly.

## 0.3.0 - behaviour

- [ ] Follow the player (basic pathfind to a moving target).
- [ ] Simple state machine: Idle / Follow / Hold position, switchable from the
      window and the right-click menu.
- [ ] Combat: let it defend itself against zombies.

## 0.4.0 - the "little help"

- [ ] Give the NPC a role: carry loot, guard a spot, hand over items.
- [ ] Inventory transfer UI (reuse the vanilla trade/loot panes if possible).
- [ ] Basic needs or an "it just works" toggle in sandbox options.

## Later / maybe

- [ ] Multiplayer-safe path (server owns NPC state, clients send requests).
- [ ] Sandbox options page (spawn cost, cap, hostility, needs on/off).
- [ ] Steam Workshop packaging (`workshop.txt`, `preview.png`, `Contents/mods/`).

## Open questions

- Does B42 expose usable NPC/animal AI hooks we can lean on, or do we drive
  everything from `IsoGameCharacter` + timed actions ourselves?
- Model/animation set for a survivor that isn't a zombie.
- How much of the vanilla "companion" groundwork (if any) already exists in B42
  and is callable from Lua.
