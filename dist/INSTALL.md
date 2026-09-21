# A custom map for "Sir, We Have an Orc Problem"

An extra level, and a map editor if you want to draw your own.

This is not official, and it is not made by the people who made the game. It does not
change the game itself — it puts three small files next to it, and you can take them
away again whenever you like. Your saves are not touched.

## Installing on Windows

1. Unzip this folder somewhere, if you have not already.
2. Double-click **install.bat**.
3. It asks you two questions. Answer them, and it does the rest.

    - *Do you want the map editor too?* — say yes if you fancy drawing your own maps.
    - *Unlock the new map now?* — the map normally appears after you have beaten
      Level 6.2. Say yes to play it straight away.

4. Start the game through Steam as usual.

If Windows says it cannot find the game, it will tell you what to do: in Steam,
right-click the game, choose Manage, then Browse local files. Copy the address of the
folder it opens, and run `install.bat` again — it will ask for it.

## Installing on Linux

Open a terminal in this folder and run one of:

    ./install.sh                     just the map
    ./install.sh --editor --cheats   the map editor too, and unlock it now

## Playing it

The map is at the bottom of the **Levels** list, after Level 6.2. It is called
Squeers' Gauntlet: a big square arena with three broken rings of rock around your base,
and orcs coming in from all four sides.

## Drawing your own maps

If you installed the editor, press **F11** while the game is running.

    click and drag      paint
    right-click drag    rub out
    G                   ground, the bit orcs walk on
    R                   rock, which they cannot walk through
    B                   your base, the bit they are trying to reach
    1 to 9              how big the brush is
    S                   place the points orcs come in from
                        (click to add, drag to move, right-click to remove)
    Ctrl+N              start a brand new map
    Ctrl+T              give it a name
    Ctrl+S              save it
    Ctrl+Z              undo
    F5                  save it and play it right now
    F11                 put the editor away

You are drawing straight onto the game's own picture of the map, so what you see is
what you get when you play it. Your maps are saved in the same folder as this one, and
you can zip that folder up and send it to somebody else.

Every map needs a bit of **base** painted somewhere, or the orcs will wander in with
nothing to walk towards. The editor will warn you if you forget.

## Removing it

Double-click **uninstall.bat** on Windows, or run `./install.sh --uninstall` on Linux.
Your maps and your saves are left where they are.

## The small print

- A future update to the game could stop this working. If that happens, remove it.
- The maps you make are yours. Nothing belonging to the game is included here.
- Made with the loader and editor at <https://github.com/lawless-m/Orcs>.
