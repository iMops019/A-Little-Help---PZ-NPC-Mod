# Changelog

All notable changes to **A Little Help** are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
