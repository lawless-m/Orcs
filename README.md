# Custom maps for "Sir, We Have an Orc Problem" (Steam appid 4594150)

The game has no Workshop support and no mod hooks of its own, but it is a Godot 4.6
export, and Godot reads an `override.cfg` sitting next to the executable. That is
enough to register an autoload, which may live in `user://` — so nothing in the Steam
folder is patched except one small text file.

## Install

    install.bat                  # Windows -- double-click it
    ./install.sh --cheats        # Linux

The editor always goes in -- nobody wants the map and not the editor. `--cheats`
puts an Unlock button on every level, so you need not replay the campaign to reach
your own map. `install.bat` asks that one question and calls `install.ps1`. The installers find the game through Steam -- every library, not just the default --
put the three files in place, and never replace a map you already have. `--uninstall`
takes it back out and leaves your maps and saves alone. If the game cannot be found,
pass the folder with `--game-path` / `-GamePath`.

To do it by hand instead, copy `override.cfg` next to the game binary:

    ~/.local/share/Steam/steamapps/common/Sir, We Have an Orc Problem/

Copy `mod_loader.gd` and the `mods/` folder into the user data directory:

    ~/.local/share/Sir, We Have an Orc Problem/

On Linux `mod_loader.gd` and `mods` can be symlinks back into this folder, so the repo
stays the single source of truth while you work — the game follows them. Keep
`override.cfg` a real copy, since your own may differ from the shared default (see
Cheats below). To uninstall, delete the three paths. The game binary is never
modified.

## Making a map

A map is an RGBA PNG. One pixel is one tile; the world is 8 units per pixel.

| Pixel                      | Meaning              |
|----------------------------|----------------------|
| transparent `(0,0,0,0)`    | open ground          |
| blue `(0,0,255,255)`       | solid rock           |
| red `(255,0,0,255)`        | your base            |

Red and blue are independent channel flags. Do not use anti-aliasing or a soft brush —
the channels are read exactly.

The twelve stock maps make good starting points, but they are the developers' artwork
and are deliberately **not** in this repository. Generate them locally into
`reference/` (which is gitignored) by adding this to `mod_loader.gd`'s `_ready()`,
running the game once, and then taking it out again:

```gdscript
DirAccess.make_dir_recursive_absolute("user://reference")
await get_tree().process_frame
for k in GameManager.levels:
	var d: LevelData = GameManager.levels[k].data
	d.map_texture.get_image().save_png("user://reference/map_%s.png" % k)
	d.sprite_sheet_texture.get_image().save_png(
		"user://reference/%s" % d.sprite_sheet_texture.resource_path.get_file())
```

Sprite sheets available: `grass`, `ice`, `desert`, `lava`, `stone`, `cave`.

Each folder under `mods/` needs the PNG and a `level.json`:

```json
{
  "name": "Squeers' Gauntlet",
  "map": "map.png",
  "sprite_sheet": "res://levels/sprite_sheet_stone.png",
  "wall_tiles_count": 2,
  "ground_tiles_count": 2,
  "enemy_health_buff": 8.0,
  "level_bonus_marks": 500,
  "marks_upon_survival": 2000,
  "marks_upon_all_killed": 0,
  "spawners": [
    { "position": [-20, 64], "size": [20, 60], "initial_velocity": [50, 0],
      "waves": [ { "enemy_type": 0, "amount": 3000, "duration": 45.0 } ] }
  ]
}
```

Spawner positions are in world units, and sit just outside the map edge so the orcs
walk in.

Maps appear at the bottom of the level list, after Level 6.2.

## Map preview (F9)

**F9 shows you your map. It does not let you change it.** Changing it means editing
the PNG in a paint program and the numbers in `level.json`.

What F9 does give you is the game drawing your map exactly as the battle will: the
rock and the ground, the paths the orcs will take through it, and the outlines they
will bump into. It also prints the figures that decide how hard the map is — how many
orcs, how fast they arrive, and their average and total health. Press F9 again for
your next map, **F10** to close it. Each press re-reads the PNG and the JSON from
disk, so you can paint, tap F9, and see the result straight away.

### Why only a preview

The developers left their own map-building tool inside the game they shipped. The half
of it that draws still works. The half that edits was never in there: it was the Godot
editor's property panel and drag handles, which exist only inside the editor, not in a
game you download. Its save button is stranded here too — it writes back into the
game's own files, which cannot be written to.

### If you are changing this code

The preview is drawn on a layer over the top of the running game, and nothing in the
live scene is touched. Do not be tempted to swap scenes instead: freeing the scene
while a tooltip is showing leaves the tooltip pointing at a window that no longer
exists, and the game dies. `ResourceSaver` itself works perfectly well at runtime if
you point it at `user://`; only the tool script's hardcoded destination is the problem.
ESC cannot be used as a key here either, because the game handles `ui_cancel` first
and swallows it.

## Painting maps (F11)

`editor.gd` is a map painter that runs inside the game. The installers put it in
place; by hand, it is the `MapEditor` line in `override.cfg`.

    F11          open the painter, and close it again
    F5           save and play this map straight away

    G R B        paint ground, rock or base
    1 - 9        brush size, in cells across
    left drag    paint             right drag   erase to open ground

    S            place spawn points instead of painting; G, R or B comes back
                 click to place, drag to move, right-click to remove

    Ctrl+S       save              Ctrl+Z       undo
    Ctrl+N       start a new map   Ctrl+T       rename this map
    Ctrl+O       total orcs, shared out between the spawn points
    N            move to your next map
    Ctrl+E       copy the stock maps and sheets to user://reference/
    middle drag  pan               wheel        zoom

You are painting on the game's own renderer, not a mock-up. Stop moving the brush and
the world rebuilds about 80 ms later -- 29 ms of work for a 192x192 map -- so the rock,
the tiles and the paths you see are what the battle will draw. A cell grid appears once
you are zoomed in far enough for it to be legible.

Spawn points are drawn in both modes, with an arrow for the direction the orcs enter;
a new one faces the middle of the map so there is no velocity to work out by hand.

Ctrl+S writes `map.png` and `level.json` back into the map's own folder -- the image
holds the ground, the JSON holds the spawn points and the name -- and keeps one
`map.png.bak` from before the first save of each session.

A map with no base is not broken, but it has no lose condition: the orcs pour in and
mill about with nothing to walk to. The HUD says so rather than letting you find out
in a battle.

### Starting a new map

**Ctrl+N.** It makes `mods/map_2/` with a `level.json`, opens it as a blank walled box
and registers it in the level list straight away. Rename it by editing `name` in that
`level.json`, and change `map_size` there before you paint if you want it bigger or
smaller than 128x128.

`template/` holds the same `level.json` for anyone who would rather set a map up from
outside the game: copy it to `mods/<your map>/`. There is no PNG in either case -- the
loader makes the blank box the first time it reads a folder without one.

## Cheats / dev menu

The first line of `override.cfg` (before any `[section]`) turns cheats on:

    _custom_features="steam,cheats"

With it, the dev menu is permanently visible at the **bottom left of the tech tree**
(time played, marks spent, Can Refund Upgrades, currency buttons, Reset Stats). The D
key toggles it, but D also pans the tech tree camera, so it is easier to just look.

To reach a custom map without replaying the campaign, use the **Unlock** button that
appears on each panel in the Levels list — press the one on your own level and it
unlocks directly. The dev menu's currency buttons only grant marks and tokens; they do
not mark levels as survived.

## Progress

Custom levels save like any other, into the same save slot: survived, all-orcs-killed,
your tower layout and the per-level stats. The game already writes them; the loader
restores them, because `GameManager.load_data()` only rebuilds the stock twelve and we
register afterwards.

Level ids are assigned in sorted folder order after the stock levels, and the save is
keyed by id — so renaming a folder in a way that reorders it will move progress with
the id, not with the map.

## Known limits

- A game update that reworks `GameManager` may need the loader adjusted.
- Custom levels go through the normal Steam achievement path.

## Licence

MIT, covering the loader, the scripts and the maps in this repository. It does not and
cannot cover anything belonging to "Sir, We Have an Orc Problem" — no game asset is
redistributed here. This is an unofficial add-on, unaffiliated with the developers.
