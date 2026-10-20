extends RefCounted

## Spójna trasa map (docs/znane_problemy.md „Spójna ścieżka postępu między mapami”). Każda mapa głównego łańcucha
## zapisuje w zapisie gry (LevelStateManager.map_links, klucz = nazwa sceny): krawędź wejścia, z którą powstała,
## dozwolone krawędzie wyjścia, faktyczną krawędź wyjścia i pole na siatce świata [x, y, warstwa].
## Następna mapa (jej previous_level_path = ta mapa) dostaje wejście na krawędzi przeciwnej do wyjścia poprzedniej
## (przyszliśmy z tamtej strony), a wyjście nie w stronę pola zajętego już przez inną mapę. Przejście bez krawędzi
## (drabina, schody w ścianie: -1) prowadzi na nową warstwę siatki (inne piętro). Ograniczenia mapy zostają takie,
## z jakimi powstała — ponowne generowanie (inny plik mapy, powrót) daje tę samą mapę. Krawędzie: 0 N, 1 E, 2 S, 3 W.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func opposite(edge: int) -> int:
	return (edge + 2) % 4 if edge >= 0 else -1


## Ograniczenia generowania mapy `name` (poprzednia w łańcuchu: `prev_name`): {"in": krawędź wejścia (-1 = dowolna),
## "allow": [dozwolone krawędzie wyjścia] (puste = dowolne), "pos": [x, y, warstwa] (puste = nieznane)}.
static func constraints(links: Dictionary, name: String, prev_name: String) -> Dictionary:
	var own: Variant = links.get(name)
	if own is Dictionary:
		return {"in": int(own.get("in", -1)), "allow": _ints(own.get("allow", [])), "pos": _ints(own.get("pos", []))}
	var prev: Variant = links.get(prev_name)
	var p: Array[int] = []
	if prev is Dictionary:
		p = _ints(prev.get("pos", []))
	if p.size() != 3:
		return {"in": -1, "allow": [] as Array[int], "pos": [] as Array[int]}
	var out := int(prev.get("out", -1))
	var pos: Array[int] = [p[0], p[1], p[2] + 1]
	if out >= 0:
		pos = [p[0] + DIRS[out].x, p[1] + DIRS[out].y, p[2]]
	var in_edge := opposite(out)
	var taken := _taken(links)
	var allow: Array[int] = []
	var any: Array[int] = []
	for e in range(4):
		if e == in_edge:
			continue
		any.append(e)
		if not taken.has(Vector3i(pos[0] + DIRS[e].x, pos[1] + DIRS[e].y, pos[2])):
			allow.append(e)
	return {"in": in_edge, "allow": allow if not allow.is_empty() else any, "pos": pos}


## Zapisuje mapę po wygenerowaniu: ograniczenia, z którymi powstała (`cons` z constraints), i faktyczną krawędź wyjścia.
## Mapa bez znanego poprzednika (pierwsza, stary zapis) dostaje własną warstwę siatki. Wpis już jest — tylko "out".
static func record(links: Dictionary, name: String, cons: Dictionary, out_edge: int) -> void:
	if links.get(name) is Dictionary:
		links[name]["out"] = out_edge
		return
	var pos := _ints(cons.get("pos", []))
	if pos.size() != 3:
		pos = [0, 0, _free_layer(links)]
	links[name] = {"in": int(cons.get("in", -1)), "allow": _ints(cons.get("allow", [])), "pos": pos, "out": out_edge}


static func _taken(links: Dictionary) -> Dictionary:
	var out := {}
	for k in links:
		if not (links[k] is Dictionary):
			continue
		var q := _ints((links[k] as Dictionary).get("pos", []))
		if q.size() == 3:
			out[Vector3i(q[0], q[1], q[2])] = true
	return out


static func _free_layer(links: Dictionary) -> int:
	var top := -1
	for v in _taken(links):
		top = maxi(top, (v as Vector3i).z)
	return top + 1


## Tablica liczb z zapisu (JSON zamienia int na float).
static func _ints(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out
