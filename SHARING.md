# Sharing the map

## Build the package

    ./package.sh gauntlet          # Linux, macOS, WSL, Git Bash
    ./package.ps1 gauntlet         # Windows PowerShell

That writes `dist/gauntlet.zip` — about 12 KB, seven files. Both scripts produce a
byte-identical package. Run one again after any change to the map or `level.json`.

There is no script at all on Windows if you would rather not use one: the zip is just
`override.cfg`, `mod_loader.gd`, `dist/INSTALL.md` and your own folder from `mods/`.
Select those four, right-click, Send to -> Compressed folder.

The scripts do three things that are easy to get wrong by hand:

- **Package only the named map.** `mods/` may hold other people's maps, and shipping
  someone else's work inside your release is not on.

- **Ship a cheats-free `override.cfg`.** The repo default has that line commented out
  and the packaged config omits it entirely. Handing a stranger a silently
  cheat-enabled game is rude. Your own installed copy is a separate file with the line
  uncommented, so the two never get confused.
- **Leave out `reference/`.** Those twelve maps and six sprite sheets were extracted
  from the game. They are the developers' artwork and are fine as a local working
  reference, but must not be redistributed. Nothing in the zip comes from the game —
  just your map PNG, the loader script and the install guide. `level.json` refers to
  the game's sprite sheet by path, so no art travels with it.

## What the recipient gets

The zip carries `install.sh` and `install.ps1`, so for most people it is one command.
`INSTALL.md` covers both those and the by-hand route. Where things go:

| File | Goes to (Windows) | Goes to (Linux) |
|---|---|---|
| `override.cfg` | `...\steamapps\common\Sir, We Have an Orc Problem\` | `~/.local/share/Steam/steamapps/common/Sir, We Have an Orc Problem/` |
| `mod_loader.gd`, `mods/` | `%APPDATA%\Sir, We Have an Orc Problem\` | `~/.local/share/Sir, We Have an Orc Problem/` |

The Windows save path comes from the project setting `use_custom_user_dir = true` with
no custom name, so Godot uses the project name under `%APPDATA%`. The Windows build
carries a byte-identical pack to the Linux one (same 1,219 files), so it behaves the
same — though the Windows path itself has not been tested here.

## Where to post it

There is no Workshop for this game, so Steam cannot host the file. Post the zip
somewhere and link to it:

- **The game's Discord** — <https://mumpitzgames.com/discord>, linked from the game's
  own main menu. Best fit: you can attach the zip directly and reach the developers.
- **Steam Community hub** for appid 4594150 — a Guide takes screenshots and formatted
  text nicely, with a link out to the file. Discussions work for a smaller post.
- **A GitHub release** if you want a stable link that is not a chat attachment.

Your Steam screenshot is in
`~/.local/share/Steam/userdata/11678446/760/remote/4594150/screenshots/`.

## What to say up front

Be plain about the four things that will otherwise generate complaints:

1. It is unofficial and unaffiliated with the developers.
2. The game is never modified — it is a config file beside the executable plus two
   files in the save folder. Uninstalling is deleting three things.
3. A game update could change the internals it relies on and stop it working.

Progress on custom levels *is* saved, into the player's normal save slot, so that is no
longer a caveat.

It is also worth saying it is a mod loader, not just one map: any number of folders
under `mods/` show up in the list, so other people can drop their own maps in beside
yours.
