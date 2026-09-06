# Changelog

All notable changes to **A Little Help** are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- **Follow / Stay** (`feat(command)`, C-3): helper right-click submenu toggles
  **Follow me** <-> **Stay**. `ALH.follow` sets `rec.order = "follow"` and
  `OnTick` re-paths to the player every 800 ms while > 2 tiles away; `ALH.stay`
  clears the order and `z:setPath2(nil)`. Row shows `(following)`.
- **"Send helper here" command** (`feat(command)`, C-2): right-click the ground
  while a helper is selected -> "Send `<name>` here" -> `ALH.goTo(rec, square)`
  paths it to that tile. `ALH.selected` (set by right-click *Select*, mirrored
  from the window's list selection) is the command target. `comeHere`/`goTo`
  now share `ALH.orderTo`; row shows `(going)`; the order clears on arrival.
- **"Come here" command** (`feat(command)`, C-1): the helper right-click submenu
  gains **Come here** -> `ALH.comeHere(rec)` calls `z:pathToLocation(playerSquare)`
  (the debug menu's "Walk Here" recipe; `PathFindBehavior2`-driven, so the
  per-tick target-clear doesn't cancel it). The list row shows `(coming)` until
  the helper is within ~2 tiles. First movement order - Phase C / D build on it.
- **Right-click a helper** (`feat(ui)`, B-4): right-clicking a tile a living
  helper stands on adds a top-level `<name>  (helper)` option -> **Select**
  (open the window, highlight its row) / **Send away** (remove it). `helpersAt()`
  finds them by proximity to the clicked square since `worldobjects` never
  contains characters. This submenu is where movement/work commands will go.
- **Live helper status in the list** (`feat(ui)`, B-3): each row shows
  `name -- N tiles` (distance to the player) or `name -- dead`, refreshed ~4x/sec
  while the window is open (`prerender` -> `updateRows`, text-only so selection
  and scroll are kept). Replaces the stale spawn-coordinate readout.
- **Spawn a tamed-zombie helper** (`feat(spawn)`, B-1): Spawn NPC / *Spawn NPC
  Here* calls `createZombie(x, y, z, nil, 0, IsoDirections.S)` (the B42
  single-zombie global), marks it (`ModData.alhTamed`), `setNoTeeth(true)`, and
  an `OnTick` hook clears each helper's target so it won't chase. Records a name
  from `SurvivorFactory.CreateSurvivor`. Remove -> `removeFromWorld`. Lore: it's
  a "kinda cured" infected - the horde ignores it because it still reads as
  infected. No appearance change or follow yet.
- Rejected `IsoSurvivor` as the NPC class: dead code in B42 (constructor nulls
  the `final` `bodyDamage`, inherited `update()` NPEs on it every tick; `Say()`
  casts to `IsoPlayer`). Rejected headless `IsoPlayer` (world player-slot
  assumptions). See `docs/ARCHITECTURE.md`.

- **ESC closes the window** (`feat(ui)`): when the helper window is open, ESC
  closes it and is consumed, so it doesn't also open the pause menu; a second ESC
  does. Standard vanilla build/craft/map behaviour.
- **Window remembers its position/size** (`feat(ui)`): a G-toggle reopens the
  window where you left it (`ALH.windowRect`), and it survives a game restart via
  `ISLayoutManager` (`Zomboid/Lua/layout.ini`). `devReload` reuses this instead
  of its own position dance.
- **Focus guard** (`feat(keybind)`): `G` no longer toggles the window while the
  player is entering text (chat, rename dialog, map search, debug console). Done
  by moving the toggle from `OnKeyPressed` to `OnKeyStartPressed`, which the
  engine suppresses while a text field has keyboard focus - no manual detection.
- **Hot reload** (`feat(core)`): `-debug` sessions get a "Reload ALH lua (dev)"
  button in the window that re-runs every ALH file via `reloadLuaFile` - no game
  restart. New `ALH_00_Core.lua` owns the namespace, `ALH.log`, `ALH.hookEvent`
  (reload-safe event registration), and `ALH.devReload`.
- `deploy.ps1 -Debug` launches PZ with `-debug`.
- `docs/ENGINEERING.md` - working method (small vertical slices), Definition of
  Done, PZ modding reference, code standards, hot-reload contract.

### Changed
- `ALH.hookEvent` now records `{event, fn}` per key, so a hot-reload that moves a
  handler between events detaches it from the right one.
- Client lua files renamed with `_NN_` load-order prefixes
  (`ALH_00_Core` … `ALH_40_ContextMenu`) so Core is guaranteed to load first.
- `Main` / `ContextMenu` / `Keybinds` refactored to be idempotent (safe to
  re-execute): event handlers go through `ALH.hookEvent`, keybind rows are
  dupe-guarded. `ALH.toggleMenu` split into `openMenu` / `closeMenu` /
  `toggleMenu`.

### Fixed
- **B42 was silently skipping the mod** - not in the Mods list, stripped from
  `default.txt` at launch, nothing loaded. Two real causes, found by
  disassembling `projectzomboid.jar`:
  1. `ZomboidFileSystem.getAllModFoldersAux` only registers a folder in
     `Zomboid/mods/` if it has `common/mod.info` or `<version>/mod.info`. Our
     flat `media/` + root `mod.info` was invisible. **Moved everything under
     `common/`.**
  2. `mod.info` was LF-only (from `.gitattributes eol=lf`); PZ's line parser
     produced no `id`. **Pinned `mod.info` to CRLF** in `.gitattributes`;
     `deploy.ps1` re-forces CRLF on copy.
- (The earlier `poster.png` guess was wrong - poster is cosmetic. Kept it anyway;
  every real mod ships one.)

### Added
- `common/` wrapper; `poster.png` + `icon.png`; `mod.info` gains `poster=`,
  `icon=`, `modversion=`.
- `deploy.ps1` auto-enables the mod: inserts `mod = ALittleHelp,` into
  `Zomboid\mods\default.txt` (the New Game load-order list), idempotently.
  `-Saves latest|all` patches existing saves' `mods.txt`; `-Launch` starts the
  game (console build); `-NoEnable` skips the list edits.
- `dev-deploy.bat` - double-click wrapper for `deploy.ps1`.

### Changed
- Mod payload restructured `media/` -> `common/media/`; `deploy.ps1` mirrors
  `common/` and writes CRLF `mod.info` to both `common/` and the deployed root.

## [0.1.0] - 2026-09-05

Initial scaffold. UI and hooks only - nothing is spawned in the world yet.

### Added
- `mod.info` for Project Zomboid Build 42 (tested on 42.20.4).
- **Keybind** `[A Little Help] > ALH: Toggle helper menu`, default `G`,
  rebindable in Options > Key Bindings.
- **Helper window** (`ALH_NPCMenu`, an `ISCollapsableWindow`): draggable,
  resizable, dark theme. Contains:
  - a **Tracked NPCs** scrolling list box
  - buttons: **Spawn NPC** (accent), **Remove**, **Refresh**, **Close** (cancel)
- **World right-click submenu** `ALH NPC`:
  - *Spawn NPC Here* - stubs an entry at the clicked square
  - *Open Helper Menu (G)*
  - *Tracked NPCs: N* (disabled info row)
- `ALH` Lua namespace: `ALH.npcs`, `ALH.spawnNPC(square)`, `ALH.removeNPC(stub)`,
  `ALH.toggleMenu()`, `ALH.log(msg)`.
- `deploy.ps1` - copies `media/` + `mod.info` into the local game mods folder.
- Docs: `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`.

### Known gaps
- `Spawn NPC` only appends a placeholder table - no `IsoGameCharacter` is created.
- `G` still toggles while typing in chat (no focus guard).
- No `poster.png`.
- Single-player, client-side only.
