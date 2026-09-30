class_name TerrainAutotileSolver
extends RefCounted

## Własny solver autotilingu terenu — zastępuje TileMapLayer.set_cells_terrain_connect,
## który przy nakładających się terenach (mud w ground itd.) generuje niemożliwe stany
## bitów i wstawia zły kafel (Godot bug #70218, asymetrycznie — stąd twarde cięcia po
## prawej). Zamiast tego liczymy wzorzec sąsiedztwa wprost z malowanego zbioru komórek
## i wybieramy kafel o pasujących bitach terenu (jak zrobiłby to edytor).
##
## Kolejność bitów (indeksy 0..7): TL, T, TR, L, R, BL, B, BR.

const OFFS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                    Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)]

const NEIGH := [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,                                       TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]

# Bok (T/L/R/B) waży więcej niż narożnik — błędny bok = widoczne twarde cięcie.
const BIT_COST := [1, 2, 1, 2, 2, 1, 2, 1]


## Buduje listę kafli danego terenu: Array of [mask, source_id, atlas_coords] + słownik dokładnych.
static func _build_lookup(ts: TileSet, terrain_set: int, terrain: int) -> Array:
	var exact := {}
	var all: Array = []
	var by_vertex := {}
	for si in range(ts.get_source_count()):
		var sid := ts.get_source_id(si)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		for ti in range(src.get_tiles_count()):
			var coord := src.get_tile_id(ti)
			var td := src.get_tile_data(coord, 0)
			if td == null or td.terrain_set != terrain_set or td.terrain != terrain:
				continue
			var mask := 0
			for i in range(8):
				if td.get_terrain_peering_bit(NEIGH[i]) == terrain:
					mask |= (1 << i)
			all.append([mask, sid, coord])
			if not exact.has(mask):
				exact[mask] = [sid, coord]
			var vk := _vertex_key(mask)
			if not by_vertex.has(vk):
				by_vertex[vk] = [sid, coord]
	return [exact, all, by_vertex]


## Wierzchołki z maski 8 sąsiadów (bity TL, T, TR, L, R, BL, B, BR): wierzchołek = oba boki + narożnik.
## Kafel terenu zależy tylko od wierzchołków — narożnik bez boków nic nie zmienia na obrazku.
static func _vertex_key(mask: int) -> int:
	var v := 0
	if mask & 0b00001011 == 0b00001011: v |= 1   # TL: TL, T, L
	if mask & 0b00010110 == 0b00010110: v |= 2   # TR: T, TR, R
	if mask & 0b01101000 == 0b01101000: v |= 4   # BL: L, BL, B
	if mask & 0b11010000 == 0b11010000: v |= 8   # BR: R, B, BR
	return v


static func _weighted_cost(a: int, b: int) -> int:
	var diff := a ^ b
	var cost := 0
	for i in range(8):
		if diff & (1 << i):
			cost += BIT_COST[i]
	return cost


## Maluje teren na warstwie: dla każdej komórki liczy wzorzec (sąsiad w zbiorze = ten teren)
## i ustawia kafel o dokładnie pasujących bitach; potem o tych samych wierzchołkach (narożnik bez
## boków nie ma znaczenia); przy braku — najbliższy wg wagi (bok > narożnik).
static func paint(layer: TileMapLayer, cells: Array, terrain_set: int, terrain: int) -> void:
	var prep := prepare(layer, cells, terrain_set, terrain)
	if not prep.is_empty():
		paint_range(layer, cells, prep, 0, cells.size())


## Tablice dobierania kafli + zbiór kratek terenu dla paint_range. Puste = nie ma czego malować.
static func prepare(layer: TileMapLayer, cells: Array, terrain_set: int, terrain: int) -> Dictionary:
	if cells.is_empty() or layer.tile_set == null:
		return {}
	var lut := _build_lookup(layer.tile_set, terrain_set, terrain)
	if (lut[1] as Array).is_empty():
		return {}
	var cellset := {}
	for c in cells:
		cellset[c] = true
	return {"lut": lut, "cellset": cellset}


## Kratki cells[from..to) — kafel zależy tylko od pełnego zbioru kratek (prepare), więc malowanie
## porcjami daje to samo co paint().
static func paint_range(layer: TileMapLayer, cells: Array, prep: Dictionary, from: int, to: int) -> void:
	var exact: Dictionary = prep.lut[0]
	var all: Array = prep.lut[1]
	var by_vertex: Dictionary = prep.lut[2]
	var cellset: Dictionary = prep.cellset
	for idx in range(from, mini(to, cells.size())):
		var c = cells[idx]
		var mask := 0
		for i in range(8):
			if cellset.has(c + OFFS[i]):
				mask |= (1 << i)

		var pick
		var vk := _vertex_key(mask)
		if exact.has(mask):
			pick = exact[mask]
		elif by_vertex.has(vk):
			pick = by_vertex[vk]
		else:
			var best_cost := 1 << 30
			var best_bits := 99
			for e in all:
				var cost: int = _weighted_cost(mask, e[0])
				# przy remisie preferuj mniej ustawionych bitów (mniej "rozlania" terenu)
				var bits := _popcount(e[0])
				if cost < best_cost or (cost == best_cost and bits < best_bits):
					best_cost = cost
					best_bits = bits
					pick = [e[1], e[2]]

		layer.set_cell(c, pick[0], pick[1])


static func _popcount(x: int) -> int:
	var n := 0
	while x != 0:
		n += x & 1
		x >>= 1
	return n
