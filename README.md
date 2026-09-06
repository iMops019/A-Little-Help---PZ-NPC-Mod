# A Little Help

A Project Zomboid **Build 42** NPC helper mod. Early WIP.

Target game version: 42.20.4 (B42). Written in Lua (no build step). Client-side
only, single-player. Private for now.

Repo: <https://github.com/iMops019/A-Little-Help---PZ-NPC-Mod>

## Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - how the mod is wired, load
  order, the `ALH` namespace, how to add a feature
- [docs/ROADMAP.md](docs/ROADMAP.md) - planned versions, open questions
- [CHANGELOG.md](CHANGELOG.md) - what changed per version

## What it does right now

- **Press `G`** in-game to toggle a dressed-up helper window:
  - Draggable, resizable, dark themed title-bar window
  - **Tracked NPCs** list box
  - Buttons: **Spawn NPC** (green), **Remove**, **Refresh**, **Close** (red)
- **Right-click the world** for an **`ALH NPC`** submenu:
  - *Spawn NPC Here* - stubs an NPC at the clicked tile
  - *Open Helper Menu (G)*
  - *Tracked NPCs: N* (greyed info row)
- Rebindable key under **Options > Key Bindings > "\[A Little Help\]"** (defaults to `G`).

**Nothing is actually spawned in the world yet.** "Spawn NPC" only appends a
placeholder row so the UI, list box, and hooks can be verified. Real NPC spawning
comes later.

## Project layout

```
A-Little-Help/
  mod.info                 game-facing metadata
  media/lua/client/
    ALH_Keybinds.lua       registers the G keybind
    ALH_Main.lua           ALH namespace, spawn stub, key handler, toggle
    ALH_NPCMenu.lua        the ISCollapsableWindow UI
    ALH_ContextMenu.lua    the "ALH NPC" right-click submenu
  docs/                    ARCHITECTURE.md, ROADMAP.md
  CHANGELOG.md
  deploy.ps1               dev: copy into the game + auto-enable
  dev-deploy.bat           double-click wrapper for deploy.ps1
  README.md
```

Only `mod.info` + `media/` are the mod. Everything else is repo scaffolding and
never reaches the game folder. Flat `media/` is fine on B42 42.20 - the bundled
`examplemod` uses the same layout. Add `media/lua/server/` and
`media/lua/shared/` later as needed. `docs/ARCHITECTURE.md` has the details.

## Installing / testing

There is no build step - "deploy" just copies `media/` + `mod.info` into the PZ
user folder (`C:\Users\conov\Zomboid\mods\ALittleHelp\`). `deploy.ps1` also ticks
the mod on and drops it into the load-order list the **New Game** screen reads
(`Zomboid\mods\default.txt`), so you never re-tick anything by hand.

### Deploy

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\conov\Documents\ALittleHelp\deploy.ps1"
```

or double-click `dev-deploy.bat`. Options:

| Command | Effect |
| --- | --- |
| `deploy.ps1` | copy files + enable in the New Game mod list |
| `deploy.ps1 -Saves latest` | also add it to the most recent existing save |
| `deploy.ps1 -Saves all` | also add it to every existing save |
| `deploy.ps1 -Launch` | deploy, then start PZ (console build) |
| `deploy.ps1 -NoEnable` | copy files only, touch no mod list |

### The loop

1. Run `deploy.ps1` (add `-Launch` to start the game too).
2. **New Game** - the mod screen already shows **A Little Help** enabled and in
   the order; click Next / Play through the mod-check and mod-order screens.
3. In game: press **`G`**, or right-click the ground -> **`ALH NPC`**.
4. Change code -> re-run `deploy.ps1` -> **restart PZ** (Lua is read at launch;
   with `-debug` you can `Reload Lua` from the debug menu instead).

Testing against an **existing** save instead of a new one? That save keeps its
own mod list - use `-Saves latest` (or enable the mod in that save's load screen
once).

## Debugging

- **Live log:** launch via `ProjectZomboid64ShowConsole.bat` for a console window
  that streams `[A Little Help]` prints and Lua stack traces as they happen.
- **After the fact:** `C:\Users\conov\Zomboid\console.txt`, search `[A Little Help]`.
- Launch PZ with `-debug` for the in-game debug menu (`Reload Lua`, spawn tools).
- Lua errors also surface as a red box in-game.

## Gotchas learned the hard way

- **A local mod with no `poster.png` is silently skipped by B42's scanner** - it
  never appears in the Mods list and any manual `default.txt` entry for it gets
  stripped at launch. Keep `poster.png` in the mod root.
- `Zomboid\mods\default.txt` is rewritten by the game from the Mods-screen state.
  `deploy.ps1` keeps our line in it, but if it ever vanishes: launch, open
  **Main Menu > Mods**, tick **A Little Help** once - then it persists.

## Known gaps / next steps

- Pressing `G` while typing in chat still toggles the menu (no focus guard yet)
- No real NPC actor, pathing, or persistence
- Single-player only; multiplayer `G` is the vanilla voice-chat key
