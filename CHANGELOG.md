# Changelog

All notable changes to **A Little Help** are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- **Real NPC spawn** (`feat(spawn)`, B-1): Spawn NPC / right-click *Spawn NPC
  Here* now creates an actual `IsoSurvivor` at the tile
  (`SurvivorFactory.CreateSurvivor` + `InstansiateInCell` + `cell:addMovingObject`),
  says "Hello, I'm ready to work!", and records the live actor + its
  `SurvivorDesc`. Remove takes the actor out of the world (`removeFromWorld`).
  Exploratory - `InstansiateInCell` is unused by the base game, so `spawnNPC`
  logs each step. No AI, no faction, no persistence yet.
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
