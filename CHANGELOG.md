# Changelog

All notable changes to **A Little Help** are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
