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
# Ścieżki hosta (res://modules/quiz_rpg/…) w zasobach bez UID nie istnieją samodzielnie — przepisujemy na korzeń.
# quiz_rpg_paths.gd zostaje: przelicza ścieżki zapisów między hostem a wersją samodzielną.
find "$DST" -type f \( -name '*.tscn' -o -name '*.tres' -o -name '*.json' -o -name '*.import' -o -name '*.gd' \) \
	! -name quiz_rpg_paths.gd -exec sed -i 's#res://modules/quiz_rpg/#res://#g' {} +
# Assety hosta (res://assets/…) leżą samodzielnie w _host/assets/ — przepisujemy, gdy moduł nie ma własnego pliku.
python - "$DST" <<'PY'
import os, re, sys
root = sys.argv[1]
pat = re.compile(r'res://assets/[^"\n]+')
def fix(m):
	rel = m.group(0)[len('res://'):]
	if not os.path.exists(os.path.join(root, rel)) and os.path.exists(os.path.join(root, '_host', rel)):
		return 'res://_host/' + rel
	return m.group(0)
for d, dirs, files in os.walk(root):
	if os.path.relpath(d, root).split(os.sep)[0] == '_host':
		continue
	for f in files:
		if f.endswith(('.tscn', '.tres', '.json', '.gd')):
			p = os.path.join(d, f)
			with open(p, encoding='utf-8', newline='') as fh:
				s = fh.read()
			t = pat.sub(fix, s)
			if t != s:
				with open(p, 'w', encoding='utf-8', newline='') as fh:
					fh.write(t)
PY
echo "Samodzielny projekt: $DST"
