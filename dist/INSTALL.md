# A custom map for "Sir, We Have an Orc Problem"

An unofficial add-on map. The game has no Workshop support and no mod system, so this
works by way of a config file Godot reads from next to the game executable. **The game
itself is never modified** and uninstalling is deleting three things.

## Install

**1. Copy `override.cfg`** into the folder holding the game executable:

- Windows: `...\Steam\steamapps\common\Sir, We Have an Orc Problem\`
  (Steam → right-click the game → Manage → Browse local files)
- Linux: `~/.local/share/Steam/steamapps/common/Sir, We Have an Orc Problem/`

**2. Copy `mod_loader.gd` and the `mods` folder** into the game's save folder:

- Windows: `%APPDATA%\Sir, We Have an Orc Problem\`
  (paste that into the Explorer address bar)
- Linux: `~/.local/share/Sir, We Have an Orc Problem/`

That folder already exists and holds your saves. Do not touch them.

**3. Start the game normally through Steam.** The map appears at the bottom of the
Levels list, after Level 6.2, under whatever name its `level.json` gives it. It unlocks
once you have survived 6.2.

## Uninstall

Delete `override.cfg` from the game folder, and `mod_loader.gd` and `mods` from the
save folder. Nothing else is altered.

## Extras

Press **F9** in game to open the developers' own level preview on the map: it renders
the world, the flow field and the collision polygons, and prints the balance figures.
**F10** closes it. Nothing in the running game is disturbed.

To make your own, add another folder under `mods/` with a `map.png` and a `level.json`
alongside this one — they all appear in the list. The loader, the tooling and the full
notes live at <https://github.com/lawless-m/Orcs>. A map is an RGBA PNG, one pixel per
tile, 8 world units per pixel:

| Pixel                   | Meaning     |
|-------------------------|-------------|
| transparent `(0,0,0,0)` | open ground |
| blue `(0,0,255,255)`    | solid rock  |
| red `(255,0,0,255)`     | the base    |

No anti-aliasing, no soft brushes — the channels are read exactly.

Progress on custom levels is saved like any other — survived, all-orcs-killed, your
tower layout and the stats all go into your normal save slot.

## Known limits

- A game update could change the internals this relies on and stop it working. If that
  happens, uninstall as above.
- Custom levels run through the game's normal Steam achievement path.
- Unofficial and unaffiliated with the developers. Use at your own discretion.
