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
  deploy.ps1               dev: copy media/ + mod.info into the game
  README.md
```

Only `mod.info` + `media/` are the mod. Everything else is repo scaffolding and
never reaches the game folder. Flat `media/` is fine on B42 42.20 - the bundled
`examplemod` uses the same layout. Add `media/lua/server/` and
`media/lua/shared/` later as needed. `docs/ARCHITECTURE.md` has the details.

## Installing / testing

Your PZ user folder is `C:\Users\conov\Zomboid\`. Mods live in
`C:\Users\conov\Zomboid\mods\`.

### Option A - one command (recommended)

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\conov\Documents\ALittleHelp\deploy.ps1"
```

This copies `media/` + `mod.info` to `C:\Users\conov\Zomboid\mods\ALittleHelp\`
and nothing else. Re-run it after every change.

### Option B - manual copy/paste

1. Make a folder `C:\Users\conov\Zomboid\mods\ALittleHelp\`
2. Copy `mod.info` and the whole `media\` folder into it

### Then, in-game

1. Launch Project Zomboid
2. **Main Menu > Mods** - enable **A Little Help**, restart if it asks
3. Start or load a save. If prompted for the mod list, make sure **A Little Help**
   is in the **active** column
4. In game, press **`G`**. Right-click the ground for the **`ALH NPC`** menu.

Lua changes need a game restart (or `Reload Lua` from the debug menu) to take
effect - the mods list itself only needs re-enabling if you add/rename files.

## Debugging

- Console log: `C:\Users\conov\Zomboid\console.txt` - look for `[A Little Help]` lines
- Launch PZ with `-debug` to get the in-game debug menu and Lua reload
- Lua errors surface as a red box in-game and a stack trace in `console.txt`

## Known gaps / next steps

- Pressing `G` while typing in chat still toggles the menu (no focus guard yet)
- No real NPC actor, pathing, or persistence
- No `poster.png` yet (mod shows without an image in the Mods menu)
- Single-player only; multiplayer `G` is the vanilla voice-chat key
