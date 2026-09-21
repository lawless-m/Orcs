#!/bin/sh
# Install the custom-map loader for "Sir, We Have an Orc Problem".
#
#   ./install.sh
#   ./install.sh --editor --cheats
#   ./install.sh --uninstall
#
# Nothing belonging to the game is modified: one config file goes beside the
# executable, and the loader and your maps go in the save folder.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
game_name="Sir, We Have an Orc Problem"
game_path=""; editor=0; cheats=0; uninstall=0

while [ $# -gt 0 ]; do
	case $1 in
		--editor) editor=1 ;;
		--cheats) cheats=1 ;;
		--uninstall) uninstall=1 ;;
		--game-path) shift; game_path=${1:-} ;;
		*) echo "usage: $(basename "$0") [--editor] [--cheats] [--uninstall] [--game-path DIR]" >&2; exit 1 ;;
	esac
	shift
done

# Split on newlines only: Steam library paths routinely contain spaces.
find_game() {
	[ -n "$game_path" ] && { echo "$game_path"; return 0; }
	for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" \
	            "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
		[ -d "$root" ] || continue
		# the default library, then any others named in libraryfolders.vdf
		libs=$(printf '%s\n' "$root"
		       sed -n 's/.*"path"[[:space:]]*"\(.*\)".*/\1/p' \
		           "$root/steamapps/libraryfolders.vdf" 2>/dev/null || true)
		old_ifs=$IFS
		IFS='
'
		for lib in $libs; do
			IFS=$old_ifs
			dir="$lib/steamapps/common/$game_name"
			if [ -f "$dir/swhaop.x86_64" ] || [ -f "$dir/swhaop.exe" ]; then
				echo "$dir"; return 0
			fi
			IFS='
'
		done
		IFS=$old_ifs
	done
	return 0
}

game=$(find_game)
if [ -z "$game" ]; then
	echo "Could not find $game_name." >&2
	echo "In Steam: right-click the game, Manage, Browse local files," >&2
	echo "then re-run with --game-path '<that folder>'" >&2
	exit 1
fi
user="${XDG_DATA_HOME:-$HOME/.local/share}/$game_name"
echo "game : $game"
echo "saves: $user"

if [ $uninstall -eq 1 ]; then
	for f in "$game/override.cfg" "$user/mod_loader.gd" "$user/editor.gd"; do
		[ -e "$f" ] && { rm -f "$f"; echo "removed $f"; }
	done
	echo "Your maps in $user/mods and your saves were left alone."
	exit 0
fi

{
	[ $cheats -eq 1 ] && printf '_custom_features="steam,cheats"\n\n'
	printf '[autoload]\n\nModLoader="*user://mod_loader.gd"\n'
	[ $editor -eq 1 ] && printf 'MapEditor="*user://editor.gd"\n'
} > "$game/override.cfg"
echo "wrote override.cfg"

mkdir -p "$user"
cp "$here/mod_loader.gd" "$user/"
echo "copied mod_loader.gd"

if [ $editor -eq 1 ]; then
	if [ -f "$here/editor.gd" ]; then
		cp "$here/editor.gd" "$user/"
		echo "copied editor.gd -- press F11 in game"
	else
		echo "--editor asked for, but editor.gd is not in this folder." >&2
		echo "It ships with the repository, not the player download:" >&2
		echo "  https://github.com/lawless-m/Orcs" >&2
	fi
fi

# maps are copied in, never over: yours are not ours to replace
if [ -d "$here/mods" ]; then
	mkdir -p "$user/mods"
	for m in "$here"/mods/*/; do
		[ -d "$m" ] || continue
		name=$(basename "$m")
		if [ -d "$user/mods/$name" ]; then
			echo "kept your existing mods/$name"
		else
			cp -r "$m" "$user/mods/$name"
			rm -f "$user/mods/$name"/*.bak
			echo "installed map $name"
		fi
	done
fi

echo
echo "Done. Start the game through Steam; the map is at the bottom of the Levels list."
[ $cheats -eq 1 ] || echo "It unlocks once you have survived Level 6.2 (--cheats gives an Unlock button)."
