# Custom maps for "Sir, We Have an Orc Problem"

A map editor that runs inside the game, and one map made with it to get you started.

This is not official, and it is not made by the people who made the game. It does not
change the game itself — it puts three small files next to it, and you can take them
away again whenever you like. Your saves are not touched.

## Installing on Windows

1. Unzip this folder somewhere, if you have not already.
2. Double-click **install.bat**.
3. It asks you one question: *unlock the new map now?* The map normally appears once
   you have beaten Level 6.2, so say yes if you would rather play it straight away.

4. Start the game through Steam as usual.

If Windows says it cannot find the game, it will tell you what to do: in Steam,
right-click the game, choose Manage, then Browse local files. Copy the address of the
folder it opens, and run `install.bat` again — it will ask for it.

## Installing on Linux

Open a terminal in this folder and run one of:

    ./install.sh            
    ./install.sh --cheats    also unlocks the new map straight away

## Playing it

The map is at the bottom of the **Levels** list, after Level 6.2. It is called
Squeers' Gauntlet: a big square arena with three broken rings of rock around your base,
and orcs coming in from all four sides.

## Drawing your own maps

Press **F11** while the game is running.

    click and drag      paint
    right-click drag    rub out
    G                   ground, the bit orcs walk on
    R                   rock, which they cannot walk through
    B                   your base, the bit they are trying to reach
    1 to 9              how big the brush is
    S                   place the points orcs come in from
                        (click to add, drag to move, right-click to remove)
    P                   change how the map looks: grass, ice, desert,
                        lava, stone, cave, space
    Ctrl+N              start a brand new map
    Ctrl+T              give it a name
    Ctrl+A              how big the map is (192, or 256x128)
    Ctrl+O              how many orcs attack altogether
    Ctrl+H              how tough each one is
    Ctrl+D              how many seconds they take to arrive
    Ctrl+S              save it
    Ctrl+Z              undo — anything, not just painting
    F5                  save it and play it right now
    F11                 put the editor away

You are drawing straight onto the game's own picture of the map, so what you see is
what you get when you play it. Your maps are saved in the same folder as this one, and
you can zip that folder up and send it to somebody else.

Every map needs a bit of **base** painted somewhere, or the orcs will wander in with
nothing to walk towards. The editor will warn you if you forget.

The top line shows how many orcs attack, over how long, and how tough they are.
**Ctrl+O**, **Ctrl+D** and **Ctrl+H** change those three. Orcs are shared out evenly
between your spawn points, and you can type `12k` rather than `12000`.

For a sense of scale, here is the whole game:

| Level | orcs | toughness |
|-------|-----:|----------:|
| 1.1   |   400 |   1 |
| 3.1   |  8,000 |   6 |
| 4.1   | 40,000 |  16 |
| 5.2   | 120,000 |  68 |
| 6.2   | 160,000 |  98 |

The game can handle about 262,000 orcs on screen at once. That is far more than any
level sends, because they die as fast as they arrive — but a map with no base will
pile them up until it chokes.

## Removing it

Double-click **uninstall.bat** on Windows, or run `./install.sh --uninstall` on Linux.
Your maps and your saves are left where they are.

## The small print

- A future update to the game could stop this working. If that happens, remove it.
- The maps you make are yours. Nothing belonging to the game is included here.
- Made with the loader and editor at <https://github.com/lawless-m/Orcs>.
