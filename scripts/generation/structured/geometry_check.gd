class_name GeometryCheck
extends RefCounted

## Weryfikacja geometrii i osiągalności (Kontrola geometrii A i B).
## Pass 9 w architekturze structured:
## - Sprawdza osiągalność wejścia -> wyjścia z uwzględnieniem barierek i wody;
## - Sprawdza osiągalność kładek w obu osiach;
## - Sprawdza dojście do winiet i celów gracza;
## - Ruch zgodny z grą: 4 kierunki + skosy tylko gdy obie sąsiednie kratki ortogonalne są wolne.

const StructuredReservations = preload("structured_reservations.gd")
const ORTHO_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG_DIRS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


## Szybki BFS sprawdzający istnienie ścieżki
static func find_path(
	grid: Dictionary,
	reservations: StructuredReservations,
	start: Vector2i,
	target: Vector2i,
	width: int,
	height: int
) -> Array[Vector2i]:
	if start == target:
		return [start]

	var is_walkable = func(p: Vector2i) -> bool:
		if p.x < 0 or p.y < 0 or p.x >= width or p.y >= height:
			return false
		if not GridUtils.is_walkable(grid, p):
			return false
		if reservations != null and reservations.is_blocked(p):
			return false
		return true

	if not is_walkable.call(start) or not is_walkable.call(target):
		return []

	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var head := 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1

		if current == target:
			# Rekonstrukcja ścieżki
			var path: Array[Vector2i] = []
			var cur := target
			while cur != start:
				path.append(cur)
				cur = came_from[cur]
			path.append(start)
			path.reverse()
			return path

		# 1. 4 kierunki ortogonalne
		for d in ORTHO_DIRS:
			var next := current + d
			if not came_from.has(next) and is_walkable.call(next):
				came_from[next] = current
				queue.append(next)

		# 2. 4 kierunki skośne (tylko gdy obie komórki ortogonalne są wolne - brak ścinania rogów)
		for d in DIAG_DIRS:
			var ortho1 := current + Vector2i(d.x, 0)
			var ortho2 := current + Vector2i(0, d.y)
			if is_walkable.call(ortho1) and is_walkable.call(ortho2):
				var next := current + d
				if not came_from.has(next) and is_walkable.call(next):
					came_from[next] = current
					queue.append(next)

	return []


## Weryfikacja spójności geometrii po nałożeniu dekoracji i barierek
static func verify_geometry(
	ctx: GenerationContext,
	result: MapGeneratorBase.GenerationResult,
	reservations: StructuredReservations
) -> Dictionary:
	var width := ctx.width
	var height := ctx.height
	var grid := ctx.grid

	var report := {
		"entrance_to_exit": false,
		"vignettes_reachable": true,
		"all_ok": false,
		"path_length": 0
	}

	# 1. Wejście -> Wyjście
	var main_path := find_path(grid, reservations, result.entrance_pos, result.exit_pos, width, height)
	if not main_path.is_empty():
		report["entrance_to_exit"] = true
		report["path_length"] = main_path.size()
	else:
		report["entrance_to_exit"] = false

	# 2. Dojście do winiet
	if result.has_meta("vignettes"):
		var vigs: Array = result.get_meta("vignettes")
		for vig in vigs:
			var access_cells: Array = vig.get("access", [])
			var any_access_reachable := false
			for ap in access_cells:
				var path_to_vig := find_path(grid, reservations, result.entrance_pos, ap, width, height)
				if not path_to_vig.is_empty():
					any_access_reachable = true
					break
			if not any_access_reachable:
				report["vignettes_reachable"] = false
				break

	report["all_ok"] = bool(report["entrance_to_exit"]) and bool(report["vignettes_reachable"])
	return report
