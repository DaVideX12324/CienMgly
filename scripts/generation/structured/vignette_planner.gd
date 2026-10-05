class_name VignettePlanner
extends RefCounted

## Silnik winiet dla generatora structured.
## Pass 7 w architekturze structured:
## - Biblioteka szablonów winiet (szeregi skrzyń, piramidy beczek, stoły, skrzynie ze skarbami);
## - Weryfikacja strefy dostępu (access lanes);
## - Atomowy claim w StructuredReservations (przeszkoda PROP + pas dojścia LANE);
## - Integracja z ObjectPlan.

const StructuredReservations = preload("structured_reservations.gd")


## Domyślne szablony winiet dla środowiska ścieków
static func get_default_vignettes() -> Dictionary:
	return {
		"stacked_crates": {
			"id": "stacked_crates",
			"footprint": [Vector2i(0, 0), Vector2i(1, 0)],
			"access": [Vector2i(0, 1), Vector2i(1, 1)],
			"items": [
				{"offset": Vector2i(0, 0), "source_id": 1, "atlas": Vector2i(2, 0)}, # skrzynki
				{"offset": Vector2i(1, 0), "source_id": 1, "atlas": Vector2i(3, 0)}  # beczki
			]
		},
		"sewer_table": {
			"id": "sewer_table",
			"footprint": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			"access": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
			"items": [
				{"offset": Vector2i(0, 0), "source_id": 1, "atlas": Vector2i(2, 5)}  # stół 3x2
			]
		},
		"sewer_chest": {
			"id": "sewer_chest",
			"footprint": [Vector2i(0, 0)],
			"access": [Vector2i(0, 1), Vector2i(1, 0)],
			"items": [
				{"offset": Vector2i(0, 0), "source_id": 1, "atlas": Vector2i(2, 0)}
			]
		}
	}


## Próba postawienia winiety w określonej pozycji
static func try_place_vignette(
	ctx: GenerationContext,
	result: MapGeneratorBase.GenerationResult,
	reservations: StructuredReservations,
	anchor: Vector2i,
	vignette_def: Dictionary
) -> bool:
	var footprint_offsets: Array = vignette_def.get("footprint", [])
	var access_offsets: Array = vignette_def.get("access", [])
	var items: Array = vignette_def.get("items", [])
	var vid: String = vignette_def.get("id", "vignette")

	var footprint_cells: Array[Vector2i] = []
	for off: Vector2i in footprint_offsets:
		var p := anchor + off
		if not GridUtils.is_walkable(ctx.grid, p):
			return false
		if reservations.is_reserved(p):
			return false
		footprint_cells.append(p)

	var access_cells: Array[Vector2i] = []
	for off: Vector2i in access_offsets:
		var ap := anchor + off
		if not GridUtils.is_walkable(ctx.grid, ap):
			return false
		if reservations.is_blocked(ap):
			return false
		access_cells.append(ap)

	# 1. Rezerwacja strefy dostępu (musi pozostać przechodnia)
	if not access_cells.is_empty():
		var acc_ok := reservations.claim(
			access_cells,
			StringName("vignette_access_" + vid),
			&"LANE",
			{"blocks_movement": false, "reserved_for_placement": true}
		)
		if not acc_ok:
			return false

	# 2. Rezerwacja samego obrysu winiety
	var foot_ok := reservations.claim(
		footprint_cells,
		StringName("vignette_" + vid),
		&"PROP",
		{"blocks_movement": true}
	)

	if not foot_ok:
		return false

	# 3. Zapis informacji o winiecie do result
	if not result.has_meta("vignettes"):
		result.set_meta("vignettes", [])
	var vig_list: Array = result.get_meta("vignettes")
	vig_list.append({
		"id": vid,
		"anchor": anchor,
		"footprint": footprint_cells,
		"access": access_cells,
		"items": items
	})

	return true
