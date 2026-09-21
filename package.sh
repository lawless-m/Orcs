#!/bin/sh
# Build a shareable zip of one map.
#
#   ./package.sh gauntlet   ->  dist/gauntlet.zip
#
# Ships only the named map, a cheats-free override.cfg, and the loader.
# Leaves out reference/, which holds artwork extracted from the game.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
map=${1:-}

if [ -z "$map" ] || [ ! -f "$here/mods/$map/level.json" ]; then
	echo "usage: $(basename "$0") <map-folder>" >&2
	echo "available:" >&2
	ls "$here/mods" >&2
	exit 1
fi

out=$here/dist/$map.zip
stage=$here/dist/.stage

rm -rf "$stage"
mkdir -p "$stage/mods" "$here/dist"
cp "$here/mod_loader.gd" "$here/dist/INSTALL.md" "$stage/"
cp -r "$here/mods/$map" "$stage/mods/$map"

# cheats deliberately omitted from the shared copy
printf '[autoload]\n\nModLoader="*user://mod_loader.gd"\n' > "$stage/override.cfg"

rm -f "$out"
(cd "$stage" && zip -q -r "$out" .)
rm -rf "$stage"
echo "$out"
