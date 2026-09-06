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
        client/                  loaded on the client only (this whole mod)
          ALH_Keybinds.lua
          ALH_Main.lua
          ALH_NPCMenu.lua
          ALH_ContextMenu.lua
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

Within a folder the game loads files **alphabetically**, so:

1. `ALH_ContextMenu.lua` - defines `ALH_ContextMenu.*`, registers the
   `OnFillWorldObjectContextMenu` handler. Handler body runs later, by which
   point `ALH` exists.
2. `ALH_Keybinds.lua` - pushes two rows onto the global `keyBinding` table.
3. `ALH_Main.lua` - creates the `ALH` table and everything on it, registers the
   `OnKeyPressed` handler.
4. `ALH_NPCMenu.lua` - defines the `ALH_NPCMenu` window class.

Nothing touches another file's symbols at *load* time, only at *event* time, so
the order is safe. If you add a file that must load first, prefix it (e.g.
`ALH_00_Config.lua`).

## The `ALH` namespace (`ALH_Main.lua`)

| Symbol | Purpose |
| --- | --- |
| `ALH.VERSION` | string, keep in sync with `CHANGELOG.md` |
| `ALH.KEYBIND_NAME` | must equal the `value` string in `ALH_Keybinds.lua` |
| `ALH.npcs` | array of stub tables `{ id, name, x, y, z }` - the model |
| `ALH.menu` | the live `ALH_NPCMenu` instance, or `nil` when closed |
| `ALH.log(msg)` | `print()` with an `[A Little Help]` prefix -> `console.txt` |
| `ALH.spawnNPC(square)` | append a stub (no world actor yet); refreshes the menu |
| `ALH.removeNPC(stub)` | drop a stub; refreshes the menu |
| `ALH.toggleMenu()` | open the window, or close it if already open |

`ALH.npcs` is the single source of truth. The window is a **view** - it never
holds NPC state, it rebuilds its list box from `ALH.npcs` in `refreshList()`.

## The window (`ALH_NPCMenu.lua`)

- Derives `ISCollapsableWindow` (gives the title bar, drag, collapse, resize, X).
- `createChildren()` builds the header label, the list box, and two rows of
  buttons. It runs automatically the first time the window is added to the UI
  manager (`addToUIManager` -> `instantiate` -> `createChildren`).
- Buttons are dispatched by a string tag: each button gets `btn.internal =
  "SPAWN" | "REMOVE" | "REFRESH" | "CLOSE"`, and `onButton(btn)` switches on it.
  Add a button = add a tag + a branch.
- `close()` is overridden to also `removeFromUIManager()` and null out
  `ALH.menu`, so the next `G` press builds a fresh instance (no stale state).

## The right-click menu (`ALH_ContextMenu.lua`)

Hooks `Events.OnFillWorldObjectContextMenu(playerIndex, context, worldobjects,
test)`. Adds one top-level `ALH NPC` option carrying a submenu. Context callbacks
are invoked by the engine as `fn(option.target, param1, param2, ...)` - that is
why `onSpawnHere(worldobjects, player, square)` is ordered the way it is
(`target` = `worldobjects`, then the params passed to `addOption`).

## Adding a feature - checklist

1. State lives on `ALH` (or a new `ALH.<system>` table), not in the window.
2. Give the user a way in from **both** the window and the right-click menu where
   it makes sense.
3. New tunable numbers -> surface them somewhere runtime-editable later.
4. `ALH.log()` the important transitions so `console.txt` tells the story.
5. Update `CHANGELOG.md` and bump `ALH.VERSION`.
6. `deploy.ps1`, restart the game (or `Reload Lua` with `-debug`), check
   `console.txt` for red errors.
