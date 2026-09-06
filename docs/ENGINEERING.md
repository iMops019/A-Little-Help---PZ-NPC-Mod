# Engineering guide

How we build **A Little Help**. Read this before writing code.

---

## 1. How we work — small vertical slices

We ship one **vertical slice** at a time: a single thin capability, wired end to
end (data → logic → UI → in-game), verified in the running game, committed, and
only *then* do we start the next one.

- A slice is **one or two controls**, or **one behaviour**. Not "two buttons plus
  an inventory system plus an asset browser."
- **No wide changes.** Never touch the UI, a new system, and persistence in the
  same slice. If a change spans more than ~3 files for more than one reason,
  it's too big — split it.
- Every slice is small enough to hold in your head and to bisect if it breaks.
- If we discover a slice is bigger than it looked, we stop and re-slice rather
  than pushing through.

This is deliberate. The scarce resource is careful attention, not typing speed.
Spending it on one correct, tested slice beats spending it on five half-working
ones.

### The loop

```
edit  ->  deploy.ps1  ->  in-game "Reload ALH lua" (or restart if it was a hard change)
      ->  verify the one thing  ->  commit  ->  next slice
```

Restart PZ (not just reload) when you change: `mod.info`, keybinding
registration, anything read only at game start, or after a Java-level crash.

---

## 2. Definition of Done

A slice is done when **all** of these are true:

1. The game loads it with **no Lua error** — no red error box, `console.txt`
   clean of new stack traces.
2. The **one capability the slice was about** works in-game, confirmed by a human
   actually doing it.
3. **No regression** — the capabilities from earlier slices still work.
4. `CHANGELOG.md` has an entry; committed with a Conventional Commit message.
5. If the architecture changed, `docs/ARCHITECTURE.md` is updated in the same
   commit.

If any point fails, the slice isn't done — we fix it before moving on, we don't
stack the next slice on top.

---

## 3. Versioning, commits, changelog

- **SemVer** (`MAJOR.MINOR.PATCH`). We're `0.x` — anything may change; `MINOR`
  bumps on a new capability, `PATCH` on fixes.
- **Conventional Commits**: `type(scope): summary`.
  Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`.
  Scope is the area: `ui`, `spawn`, `core`, `deploy`, `keybind`, …
  e.g. `feat(ui): reload button for hot-reloading lua in -debug`
- **Keep a Changelog** format in `CHANGELOG.md`; an `## [Unreleased]` section
  collects entries until we tag a version.
- One logical change per commit.

---

## 4. Project Zomboid modding reference

Terms and conventions this codebase relies on.

### Runtime & structure

| Term | Meaning |
| --- | --- |
| **Kahlua** | The Java-hosted Lua 5.1 VM PZ runs. No build step; `.lua` is read directly. |
| **Lua context** | `media/lua/client`, `.../server`, `.../shared`. In single-player one process runs client + server; in MP they're separate. Shared loads first, then the context-specific tree, each **alphabetically**. |
| **`common/` wrapper** | B42 only discovers a local mod (`<user>/Zomboid/mods/<x>/`) if it has `common/mod.info` or `<version>/mod.info`. Our whole payload lives in `common/`. See `ARCHITECTURE.md`. |
| **`mod.info`** | Mod manifest (`id`, `name`, `poster`, …). Line-based parser — must be **CRLF**. |
| **Workshop** | Steam's mod host. A published package nests the mod under `Contents/mods/<id>/`. |

### Events / hooks

- The game fires named **events**; you attach a **handler** (callback) with
  `Events.<Name>.Add(fn)` and detach with `Events.<Name>.Remove(fn)`.
- Ones we use / will use: `OnKeyStartPressed`, `OnFillWorldObjectContextMenu`,
  `OnGameStart`, `OnCreatePlayer`, `OnPlayerUpdate`, `OnTick`.
- **Keybinds: prefer `OnKeyStartPressed` over `OnKeyPressed`.** The engine skips
  `OnKeyStartPressed` while a text field has keyboard focus (it lets
  `UIManager.onKeyPress` consume the key first), so a keybind won't fire while
  the player types in chat, a rename dialog, or the debug console.
  `OnKeyPressed` fires regardless and would need a manual focus guard.
- **Hot-reload hazard:** re-running a file calls `.Add` again and stacks a
  duplicate handler. Always register through `ALH.hookEvent` (see §6).

### UI — ISUI

- Widget classes are Lua tables built with `Parent:derive("Name")`; instances via
  `Class:new(...)`.
- Lifecycle: `new` → `initialise` → (`instantiate` → `createChildren`, triggered
  by `addToUIManager`) → `prerender`/`render` each frame →
  `removeFromUIManager`.
- Our window derives **`ISCollapsableWindow`** (title bar, drag, resize, close).
- Common widgets: `ISButton`, `ISLabel`, `ISScrollingListBox`, `ISTextEntryBox`,
  `ISTickBox`, `ISContextMenu`.
- Buttons dispatch via `target`/`onclick`; we tag each with `button.internal` and
  switch on it in one `onButton` method.

### World / characters (for v0.2+)

| Term | Meaning |
| --- | --- |
| **`getPlayer()` / `getSpecificPlayer(n)`** | Local player / split-screen player `n`. |
| **`IsoGameCharacter`** | Base for players, zombies, survivors, animals. |
| **`IsoSurvivor`** | B42's vestigial NPC class (`extends IsoLivingCharacter`); has `following`, `Despawn()`. |
| **`SurvivorFactory`** | `CreateSurvivor()` → `SurvivorDesc`; `InstansiateInCell(desc, cell, x, y, z)` → `IsoSurvivor`. |
| **`IsoGridSquare`** | One tile. `getCell():getGridSquare(x, y, z)`. |
| **Timed action** | `ISBaseTimedAction` subclass — a queued, interruptible character action. |

### Persistence & config

| Term | Meaning |
| --- | --- |
| **`ModData`** | Per-save key/value store. `getPlayer():getModData()`, or global via `ModData.getOrCreate("ALH")`. Auto-saved with the game; transmit in MP. |
| **Sandbox options** | Player-set knobs defined in `sandbox-options.txt`, read via `SandboxVars`. |
| **Translations** | `common/media/lua/shared/Translate/<lang>/*.txt`; looked up with `getText("IGUI_...")`. |
| **`-debug`** | Launch flag. `getDebug()` is true; unlocks the debug menu, `reloadLuaFile`, spawn tools. Gate dev-only UI on `getDebug()`. |
| **`reloadLuaFile(path)`** | Re-executes one loaded lua file at runtime. Basis of our Reload button. |

---

## 5. Code standards

- **One file, one responsibility.** Top-of-file block comment stating what the
  file owns.
- **Load order is explicit.** Client lua files carry a `_NN_` prefix
  (`ALH_00_Core`, `ALH_10_Keybinds`, …). The game loads a context alphabetically;
  the prefix makes "Core first" a fact, not a coincidence. Leave gaps between
  numbers so a file can be inserted later.
- **Namespace everything.** Lua globals are shared across *all* installed mods.
  Every global we define is `ALH` or `ALH_Prefixed`. No bare globals, ever.
- **`local` by default.** File-private helpers are `local function`.
- **No magic numbers.** Named `local` consts at the top of the file
  (`local PAD = 10`).
- **Guard clauses over nesting.** Bail early (`if not getPlayer() then return end`).
- **Model / view separation.** State lives on `ALH.*`. Widgets are dumb: they
  read `ALH.*` and render; they don't own domain state.
- **Defensive at the engine boundary.** Nil-check `getPlayer()`, squares, and any
  Java object that can be absent. Wrap genuinely risky Java calls.
- **`ALH.log()` the transitions that matter** — opened, spawned, removed,
  reloaded — prefixed so `console.txt` tells a story. Not every line.
- **YAGNI / DRY / SRP.** No abstraction until the second real use. No config knob
  until something needs to set it.
- **Comments explain _why_,** and match the density of the surrounding code.
- **Match the file you're in.** Naming, spacing, and idiom stay consistent.

---

## 6. Hot-reload contract

`-debug` sessions can re-run every ALH file live (the "Reload ALH lua" button →
`ALH.devReload`). For that to be safe, **every ALH file must be idempotent** —
running it a second time must not double anything up.

- **Event handlers:** register with `ALH.hookEvent(eventName, key, fn)`. It
  removes the previously registered function for `key` before adding the new one.
  Never call `Events.X.Add` directly.
- **Keybindings:** `ALH_10_Keybinds.lua` checks for an existing row before inserting.
- **Namespace / state:** `ALH = ALH or {}`, `ALH.npcs = ALH.npcs or {}` — keep
  existing state across the reload.
- **One-time side effects:** guard with a flag, `if not ALH.didX then ... end`.
- **The window** is closed and reopened by `devReload` so it picks up new widget
  code; don't rely on a live instance surviving a reload.

If a change can't be made reload-safe (new `mod.info`, new keybind, load-order
change), that's fine — it just needs a real game restart. Note it in the commit.
