#!/usr/bin/env bash
# Kopia modułu jako samodzielny projekt Godota: bez .git / .godot / tests, z project.godot
# (z project.godot.off) i bez _host/.gdignore — kopie zasobów hosta stają się widoczne.
# Katalog docelowy musi leżeć POZA Artefaktem Wiedzy (inaczej host zobaczy drugi moduł i zdublowane UID-y).
# Przed użyciem odśwież kopie w hoście: tools/sync_host_copies.gd.
#
# Użycie: modules/quiz_rpg/tools/make_standalone.sh <katalog_docelowy>
# Potem:  Godot --path <katalog_docelowy> --import  (pierwszy import), następnie edytor / uruchomienie.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DST="${1:?Podaj katalog docelowy (poza Artefaktem Wiedzy)}"

mkdir -p "$DST"
DST="$(cd "$DST" && pwd)"
case "$DST/" in
	"$SRC/"*) echo "Katalog docelowy nie może leżeć w module." >&2; exit 1 ;;
esac

tar -C "$SRC" --exclude=./.git --exclude=./.godot --exclude=./tests -cf - . | tar -C "$DST" -xf -
rm -f "$DST/_host/.gdignore"
mv "$DST/project.godot.off" "$DST/project.godot"
echo "Samodzielny projekt: $DST"
