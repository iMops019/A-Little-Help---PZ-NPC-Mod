# Architecture

How **A Little Help** is put together. Read this before adding a feature.

## Runtime

Project Zomboid runs **Lua 5.1** through *Kahlua* (a Java interpreter). There is
**no build step** - the game loads `.lua` files directly from the mod folder.
UI is the game's built-in **ISUI** framework (`ISCollapsableWindow`, `ISButton`,
`ISScrollingListBox`, `ISContextMenu`, ...).

Target: **Build 42** (developed against 42.20.4). Client-side, single-player.

## Folder layout

```
A-Little-Help/
  common/                        the entire mod payload
    mod.info                     metadata (id = ALittleHelp)
    poster.png  icon.png
    media/
      lua/
        client/                     loaded on the client only (this whole mod)
          ALH_00_Core.lua           namespace, log, hookEvent, devReload
          ALH_10_Keybinds.lua       Options > Key Bindings rows
          ALH_20_Main.lua           NPC-list model, window control, G key
          ALH_30_NPCMenu.lua        the ISCollapsableWindow
          ALH_40_ContextMenu.lua    the "ALH NPC" right-click submenu
      scripts/   (future)        item / recipe / vehicle definitions
  deploy.ps1                     dev: copy into the game + auto-enable
  dev-deploy.bat                 double-click wrapper for deploy.ps1
  docs/                          you are here
```

### Why `common/` and not a flat `media/`

B42's local-mod scanner (`ZomboidFileSystem.getAllModFoldersAux`, verified by
disassembly) only registers a folder under `<user>/Zomboid/mods/` if it contains
**`common/mod.info`** or **`<gameversion>/mod.info`** (e.g. `42/mod.info`). A bare
`mod.info` at the mod root is **ignored for local mods** - the folder never
appears in the Mods list and any `default.txt` entry for it is stripped at
launch, silently. (Steam Workshop mods are enumerated by a different path and
don't have this constraint, which is why most published mods still look flat.)

`common/` applies to every game version; add a `42/` (or `42.20/`) sibling later
only if we need version-specific overrides. `deploy.ps1` also drops a copy of
`mod.info`/`poster.png` at the deployed mod root - harmless, and closer to how a
Workshop package is laid out.

`deploy.ps1` mirrors `common/` into `Zomboid\mods\ALittleHelp\common\`, forces
`mod.info` to CRLF (PZ's parser is line-based), then inserts `mod = ALittleHelp,`
into `Zomboid\mods\default.txt` (the ordered list the New Game screen reads) so
the mod is pre-enabled. Idempotent. `-Saves latest|all` also patches existing
saves' `mods.txt`; `-Launch` starts the game; `-NoEnable` skips the list edits.

`common/media/lua/client/` is the only code path right now. When NPC logic needs
to run authoritatively (multiplayer, or anything the server should own) it goes in
`common/media/lua/server/`; code shared by both goes in
`common/media/lua/shared/`.

### Load order

The game loads a context's files **alphabetically**, so ALH files carry a
`_NN_` load-order prefix:

1. `ALH_00_Core.lua` - the `ALH` namespace, constants, `ALH.log`,
   `ALH.hookEvent`, `ALH.devReload`. **Must be first** - everything else calls
   `ALH.hookEvent` at load time.
2. `ALH_10_Keybinds.lua` - adds rows to the global `keyBinding` table
   (dupe-guarded). Reads `ALH.KEYBIND_NAME`.
3. `ALH_20_Main.lua` - the NPC-list model and window open/close/toggle; hooks
   `OnKeyStartPressed` for the G toggle. Reads `ALH.*` from Core.
4. `ALH_30_NPCMenu.lua` - defines the `ALH_NPCMenu` window class.
5. `ALH_40_ContextMenu.lua` - hooks `OnFillWorldObjectContextMenu`.

At *load* time a file only touches `ALH.*` that `ALH_00_Core` has already
defined; everything domain-specific is deferred to event time.

New files: pick a prefix that places them correctly (leave gaps - 10, 20, 30 -
so there's room to insert). Anything that must run before Core would also need
its own `ALH = ALH or {}` guard, but don't do that - keep Core first.

See `docs/ENGINEERING.md` section 6 for why every file must survive
re-execution.

## The `ALH` namespace

Defined in `ALH_00_Core.lua` unless noted.

| Symbol | Purpose |
| --- | --- |
| `ALH.ID` / `ALH.VERSION` | mod id; version string, kept in sync with `CHANGELOG.md` |
| `ALH.KEYBIND_NAME` | must equal the `value` string in `ALH_10_Keybinds.lua` |
| `ALH.log(msg)` | `print()` with an `[A Little Help]` prefix -> `console.txt` |
| `ALH.hookEvent(event, key, fn)` | attach an event handler; replaces the prior one for `key` (reload-safe) |
| `ALH.devReload()` | re-run every ALH lua file; `-debug` only; closes+reopens the window |
| `ALH._eventHandlers` | `key -> {event, fn}` registry backing `hookEvent` |
| `ALH.npcs` *(Main)* | array of records `{ id, name, desc, obj, x, y, z }` - the model |
| `ALH.menu` *(Main)* | the live `ALH_NPCMenu` instance, or `nil` when closed |
| `ALH.windowRect` *(Main)* | `{x,y,w,h}` of the window's last position, or `nil` for a centred default |
| `ALH.spawnNPC(square)` *(Main)* | spawn a tamed-zombie helper (`createRealZombieNow` + `setNoTeeth` + marker), add a record |
| `ALH.removeNPC(rec)` *(Main)* | `rec.obj:removeFromWorld()`, drop the record; refreshes the menu |
| `ALH.openMenu()` / `ALH.closeMenu()` / `ALH.toggleMenu()` *(Main)* | window control |
| `ALH.selectNPC(rec)` *(Main)* | open the window and select `rec`'s row (right-click "Select") |
| `ALH.comeHere(rec)` *(Main)* | walk the helper to the player (`z:pathToLocation`); sets `rec.order = "come"` |
| `ALH.rememberWindowRect(window)` *(Main)* | snapshot geometry into `ALH.windowRect` (the window calls this as it closes) |

`ALH.npcs` is the single source of truth. The window is a **view** - it never
holds NPC state, it rebuilds its list box from `ALH.npcs` in `refreshList()`.

### Window position

`ALH.windowRect` is the source of truth for where the window sits. Every close
path routes through `ALH_NPCMenu:close()`, which calls
`ALH.rememberWindowRect(self)` before teardown, so `openMenu` can put the next
one back. `openMenu` also `ISLayoutManager.RegisterWindow`s it under
`"ALH_helper"` - that restores the on-disk geometry (`Zomboid/Lua/layout.ini`)
on the first open of a session and writes it back on game save, so the position
also survives a restart. On later opens `ALH.windowRect` is re-applied after the
register call because ISLayoutManager's restore cache only refreshes on save.

## The window (`ALH_30_NPCMenu.lua`)

- Derives `ISCollapsableWindow` (gives the title bar, drag, collapse, resize, X).
- `createChildren()` builds the header label, the list box, and the button rows.
  It runs automatically the first time the window is added to the UI manager
  (`addToUIManager` -> `instantiate` -> `createChildren`). The list box height
  reserves space for the button rows, including the `-debug`-only third row.
- **List updates in two tiers.** `refreshList()` rebuilds rows when the roster
  changes (spawn / remove). `updateRows()` rewrites each row's `.text` in place
  from live data (`rowText(rec)` -> `name -- N tiles` / `name -- dead`), keeping
  selection and scroll; `prerender()` calls it ~4x/sec.
- Buttons are dispatched by a string tag: each button gets `btn.internal =
  "SPAWN" | "REMOVE" | "REFRESH" | "CLOSE" | "DEVRELOAD"`, and `onButton(btn)`
  switches on it. Add a button = add a tag + a branch.
- `close()` is overridden to snapshot geometry (`ALH.rememberWindowRect`), then
  `removeFromUIManager()` and null out `ALH.menu`, so the next `G` press builds a
  fresh instance (no stale state) in the same place.
- **ESC to close:** `setWantKeyEvents(true)` in `:new`, then `onKeyRelease`
  closes on `KEY_ESCAPE` and `isKeyConsumed` returns true for it. The engine
  runs the pause-menu handler on key *release* and skips it when a visible
  want-key-events widget consumed the key - so ESC closes this window, a second
  ESC opens the pause menu (vanilla build/craft/map behaviour).

## The right-click menu (`ALH_40_ContextMenu.lua`)

Hooks `Events.OnFillWorldObjectContextMenu(playerIndex, context, worldobjects,
test)`. Context callbacks are invoked by the engine as
`fn(option.target, param1, param2, ...)` - that is why
`onSpawnHere(worldobjects, player, square)` is ordered the way it is
(`target` = `worldobjects`, then the params passed to `addOption`).

- **`ALH NPC`** (always) -> Spawn NPC Here / Open Helper Menu / disabled
  "Helpers: N" count.
- **`<name>  (helper)`** per living helper on the clicked tile -> Come here /
  Select / Send away. `worldobjects` carries only static tile objects, not
  characters, so we find helpers ourselves: `helpersAt(square)` walks `ALH.npcs`
  for one whose square is at the clicked Z and within ~1.5 tiles
  (`DistToSquared < 2.25`). This submenu is the spine - movement/work commands
  get added here.

`ALH.selectNPC(rec)` (Main) opens the window and calls `ALH_NPCMenu:selectRec` to
highlight that helper's row.

## Commands (Phase C)

`rec.order` on a helper record is the current standing order (`nil` = idle,
`"come"` = walking to the player). `ALH.comeHere(rec)` sets it and calls
`z:pathToLocation(playerSquare)`. The `OnTick` handler clears `"come"` once the
helper is within ~2 tiles. Movement is `PathFindBehavior2`, not `target`, so
`z:setTarget(nil)` each tick (the tame) doesn't fight the walk. The list row
shows `(coming)` while the order stands.

## Spawning (Phase B)

The list is a **live roster** (Model B): a row is an NPC that exists in the world
right now. One "Spawn NPC" button; the generate/instantiate seam lives in the
code, not the UI (a two-button "Generate then Spawn" flow only earns its place if
NPC generation becomes a previewed choice - traits, outfit - which is a later
feature).

### B-1 finding: `IsoSurvivor` is a dead end in B42

The spawn *worked* - `SurvivorFactory.CreateSurvivor()` +
`SurvivorFactory.InstansiateInCell(desc, cell, x, y, z)` returned a valid
`IsoSurvivor` ("Ethel Wetzel"), and the constructor already adds it to the cell's
object list. But:

- **`IsoGameCharacter`'s constructor sets `bodyDamage` to `null` for anything
  that isn't an `IsoPlayer` or `IsoAnimal`** (verified by disassembly - the
  field is `final`). `IsoSurvivor` lands in the `null` branch.
- Its inherited `update()` calls `getBodyDamage().getNumPartsBleeding()` every
  tick -> `NullPointerException` at `IsoGameCharacter.updateInternal:9120` ->
  the game crashes.
- `Say()` also casts to `IsoPlayer` internally (`ProcessSay:7257`) -> another
  `ClassCastException`.

`IsoSurvivor` is vestigial - TIS left the class in but its update path assumes an
init its own constructor doesn't do. Not patchable from Lua. B42 has no working
friendly-NPC class; B43 is "the NPC build".

### Foundation: a **tamed zombie**

A helper is an `IsoZombie` - the only fully-wired character class we can spawn in
B42 (bodyDamage, AI, animation, sound, save/load all work). **Lore:** it's a
"kinda cured" infected. The Knox virus is suppressed, not gone - which is exactly
why the horde ignores it (zombies don't attack zombies), why it shambles, and
why it can't fully talk. "A Little Help" runs both ways: you give the infected a
little help, they give you a little help.

Rejected: headless `IsoPlayer` (engine assumes `IsoPlayer`s are controlled and
occupy world player slots - fragile).

`ALH.spawnNPC(square)`:

1. `createZombie(x, y, z, nil, 0, IsoDirections.S)` -> `IsoZombie`. This is the
   B42 single-zombie global (used by the base-game tutorial); it returns the
   handle. (`getVirtualZombieManager()` from B41 no longer exists.) Passing a
   `SurvivorDesc` as arg 4 for appearance is a B-2 experiment.
2. Validate (`nil`, then `z:getSquare()` nil = bad tile - discard with
   `removeFromWorld`).
3. `SurvivorFactory.CreateSurvivor()` + `randomName` for the display name
   (`getForename`/`getSurname` - this part of `SurvivorFactory` works fine).
4. Tame: `z:getModData().alhTamed = true` (marker), `z:setNoTeeth(true)`.
5. Record `{ id, name, desc, obj = z, x, y, z }`.

An `OnTick` hook walks `ALH.npcs` and clears each helper's target
(`z:setTarget(nil)`) so it won't chase. `OnTick` (once/tick over a tiny list),
**not** `OnZombieUpdate` (every zombie, every tick - would allocate a ModData
table per zombie).

`ALH.removeNPC(rec)` -> `rec.obj:removeFromWorld()`.

B-1 is deliberately the floor: no appearance change, no follow, no stationary
lock. Just: does a tamed zombie spawn, stand there, and leave the player alone.
Observations drive B-2 (human look via `setReanimatedPlayer` + an outfit) and
B-3 (follow via `z:pathToCharacter(player)`).

## Adding a feature - checklist

1. State lives on `ALH` (or a new `ALH.<system>` table), not in the window.
2. Give the user a way in from **both** the window and the right-click menu where
   it makes sense.
3. New tunable numbers -> surface them somewhere runtime-editable later.
4. `ALH.log()` the important transitions so `console.txt` tells the story.
5. Update `CHANGELOG.md` and bump `ALH.VERSION`.
6. `deploy.ps1`, restart the game (or `Reload Lua` with `-debug`), check
   `console.txt` for red errors.
