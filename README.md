# Custom maps for "Sir, We Have an Orc Problem" (Steam appid 4594150)

A map editor that runs inside the game, and one map made with it.

The game has no Workshop support and no mod system. This works because it is a Godot
4.6 export, and Godot reads an `override.cfg` from beside the executable — enough to
register an autoload, which may live in `user://`. So the game itself is never
modified, and uninstalling is deleting three files.

## Install

    install.bat                  # Windows -- double-click it
    ./install.sh --cheats        # Linux

`install.bat` asks one question — unlock the new map now, or earn it — and calls
`install.ps1`, which is there for anyone who wants the switches. The installers find
the game through Steam, every library rather than just the default, and never replace
a map you already have. `--uninstall` / `-Uninstall` takes it back out and leaves your
maps and saves alone. If the game cannot be found, pass the folder with `--game-path`
/ `-GamePath`.

By hand: `override.cfg` goes beside the game binary, and `mod_loader.gd`, `editor.gd`
and `mods/` go in the save folder.

| | Windows | Linux |
|---|---|---|
| game | `...\steamapps\common\Sir, We Have an Orc Problem\` | `~/.local/share/Steam/steamapps/common/Sir, We Have an Orc Problem/` |
| saves | `%APPDATA%\Sir, We Have an Orc Problem\` | `~/.local/share/Sir, We Have an Orc Problem/` |

On Linux the save-folder files can be symlinks back into this repository, so it stays
the single source of truth while you work. Keep `override.cfg` a real copy, since
yours will differ from the shared default.

## Drawing maps — F11

    F11          open the painter, and close it again
    F5           save and play this map right now
    N            move to your next map

    G R B        paint ground, rock or base
    1 - 9        brush size, in cells across
    left drag    paint             right drag    erase to open ground
    middle drag  pan               wheel         zoom

    S            place spawn points instead of painting; G, R or B comes back
                 click to place, drag to move, right-click to remove
    P            cycle how the map looks: grass, ice, desert, lava, stone,
                 cave, space

    Ctrl+A       how big the map is, in tiles (192, or 256x128)
    Ctrl+O       how many orcs altogether, shared between the spawn points
    Ctrl+H       how tough each orc is
    Ctrl+D       how many seconds they take to arrive
    Ctrl+T       what the map is called
    Ctrl+N       start a new map

    Ctrl+S       save              Ctrl+Z        undo
    Esc          cancel a typing box without changing anything
    Ctrl+E       copy the stock maps and sheets to user://reference/

You are painting on the game's own renderer, not a mock-up. Stop moving the brush and
the world rebuilds about 80 ms later — 29 ms of work for a 192x192 map — so the rock,
the tiles and the paths you see are what the battle will draw. A cell grid appears
once you are zoomed in far enough for it to be legible.

Spawn points are drawn in both modes, with an arrow for the direction the orcs enter;
a new one faces the middle of the map, so there is no velocity to work out by hand.

The number boxes take `12k`, `1.5k`, `120,000` and `2m`. For scale, the game's own
first level sends 400 orcs at toughness 1, and its last sends 160,000 at 98. About
262,000 can be alive at once before the simulation runs out of room.

Ctrl+Z undoes any of it — painting, spawn points, the look, the numbers, the size, the
name. Closing the editor with unsaved work saves rather than discarding it, because
reopening re-reads from disk.

Ctrl+S writes `map.png` and `level.json` into the map's own folder, and keeps one
`map.png.bak` from before the first save of each session.

A map with no base is not broken, but it has no lose condition: the orcs pour in and
mill about with nothing to walk to. The HUD says so rather than letting you find out
in a battle.

### Starting a new map

**Ctrl+N** makes `mods/map_2/`, opens it as a blank walled box and puts it in the
Levels list at once. Name it with Ctrl+T and size it with Ctrl+A.

`template/` holds a `level.json` for anyone who would rather set one up from outside
the game: copy the folder to `mods/<your map>/`. There is no PNG in either case — the
loader draws the blank box the first time it reads a folder without one.

## What a map is

Two files in a folder under `mods/`. That is also the unit people pass around: zip the
folder and send it, and it appears in the list beside theirs.

**`map.png`** — an RGBA image, one pixel per tile, eight world units per pixel:

| Pixel                      | Meaning              |
|----------------------------|----------------------|
| transparent `(0,0,0,0)`    | open ground          |
| blue `(0,0,255,255)`       | solid rock           |
| red `(255,0,0,255)`        | your base            |

Red and blue are independent channel flags. If you edit one in a paint program rather
than the editor, turn off anti-aliasing and soft brushes — the channels are read
exactly.

**`level.json`** — everything else. The editor writes it for you; this is what it says:

```json
{
  "name": "Squeers' Gauntlet",
  "map": "map.png",
  "sprite_sheet": "res://levels/sprite_sheet_stone.png",
  "wall_tiles_count": 2,
  "ground_tiles_count": 2,
  "enemy_health_buff": 80.0,
  "level_bonus_marks": 20000,
  "marks_upon_survival": 500000,
  "marks_upon_all_killed": 0,
  "spawners": [
    { "position": [-25, 768], "size": [20, 100], "initial_velocity": [50, 0],
      "waves": [ { "enemy_type": 0, "amount": 30000, "duration": 90.0 } ] }
  ]
}
```

Spawner positions are in world units and sit just outside the map edge, so the orcs
walk in. A folder with no PNG yet may give `"map_size": [128, 128]` instead, and the
loader draws a walled box that size.

The seven sprite sheets are `grass`, `ice`, `desert`, `lava`, `stone`, `cave` and
`space` — the last is in the game's files but no level uses it. Each needs its own
`wall_tiles_count` and `ground_tiles_count`, which is why P sets them for you.

Maps appear at the bottom of the Levels list, after Level 6.2.

## Cheats and the dev menu

The first line of `override.cfg`, before any `[section]`:

    _custom_features="steam,cheats"

The installers write it for you with `--cheats` / `-Cheats`. With it, the dev menu is
permanently visible at the **bottom left of the tech tree** — time played, marks spent,
Can Refund Upgrades, currency buttons, Reset Stats. D toggles it, but D also pans the
camera, so it is easier to just look.

To reach a custom map without replaying the campaign, use the **Unlock** button that
cheats add to each panel in the Levels list. The dev menu's currency buttons only grant
marks and tokens; they do not mark a level survived.

## Progress

Custom levels save like any other, into the same save slot: survived, all-orcs-killed,
your tower layout and the per-level stats. The game already wrote them; what was
missing was reading them back, because `GameManager.load_data()` rebuilds only the
stock twelve and we register afterwards.

Level ids are assigned in sorted folder order after the stock levels, and the save is
keyed by id — so renaming a *folder* in a way that reorders it moves progress with the
id rather than with the map. Renaming with Ctrl+T is safe; it changes the name inside
`level.json`, not the folder.

## How it works

`mod_loader.gd` reads each folder under `user://mods`, builds a `LevelData` in code and
puts it in `GameManager.levels` when the Levels list appears. Nothing is baked:
`battle.gd` runs `WorldGen` over the map texture at load, which is why a map can be a
plain PNG.

The game also ships the developers' own `@tool` level-editor script. The half of it
that draws still runs, and **F9** uses it for a read-only preview with the balance
figures. The half that edits was never in the export — it was the Godot editor's
property panel and drag handles — and its save button writes into read-only `res://`.
That is what `editor.gd` and `level.json` replace.

If you are changing this code: the editor draws on a layer over the running game and
touches nothing in the live scene. Do not swap scenes instead — freeing the scene while
a tooltip is showing leaves the tooltip pointing at a window that no longer exists, and
the game dies. ESC cannot be bound, because the game handles `ui_cancel` first and
swallows it. `ImageTexture.update()` refuses a differently-sized image, so a resize
needs `set_image()`. And Godot's format strings have no `%g`.

## Known limits

- A game update that reworks `GameManager` may need the loader adjusted.
- Custom levels go through the normal Steam achievement path.

## Licence

MIT, covering the loader, the editor, the scripts and the maps in this repository. It
does not and cannot cover anything belonging to "Sir, We Have an Orc Problem" — no game
asset is redistributed here. This is an unofficial add-on, unaffiliated with the
developers.
