class_name StructuredReservations
extends RefCounted

## Kontrakt rezerwacji pól dla układów strukturalnych (structured).
## Dzieli mapę na dwie niezależne cechy:
## 1. reserved_for_placement - zakaz stawiania obiektów danej klasy (przechodnie pasy ruchu, prześwity)
## 2. blocks_movement - faktyczne przeszkody fizyczne (barierki, woda bez kładki, kolizje rekwizytów)

## Vector2i -> Dictionary {owner: StringName, klass: StringName}
var reserved_for_placement: Dictionary = {}

## Vector2i -> bool
var blocks_movement: Dictionary = {}


## Sprawdza, czy kratka jest już zarezerwowana do stawiania obiektów
func is_reserved(p: Vector2i) -> bool:
	return reserved_for_placement.has(p)


## Sprawdza, czy kratka blokuje poruszanie się
func is_blocked(p: Vector2i) -> bool:
	return blocks_movement.get(p, false)


## Pobiera właściciela rezerwacji kratki
func get_owner(p: Vector2i) -> StringName:
	var info: Dictionary = reserved_for_placement.get(p, {})
	return info.get("owner", &"")


## Atomowa próba rezerwacji listy kratek.
## Sprawdza cały obrys. Jeśli jakakolwiek kratka koliduje — odrzuca wszystko i zwraca false.
## Bez wypierania — wcześniejsza rezerwacja jest ostateczna.
func claim(cells: Array[Vector2i], owner: StringName, klass: StringName, flags: Dictionary = {}) -> bool:
	var will_block: bool = bool(flags.get("blocks_movement", false))

	# 1. Sprawdzenie konfliktów dla wszystkich komórek
	for p in cells:
		if not _can_claim_cell(p, klass, will_block):
			return false

	# 2. Zapis atomowy
	for p in cells:
		reserved_for_placement[p] = {
			"owner": owner,
			"klass": klass
		}
		if will_block:
			blocks_movement[p] = true

	return true


func _can_claim_cell(p: Vector2i, new_klass: StringName, will_block: bool) -> bool:
	# Jeśli komórka nie była jeszcze zarezerwowana
	if not reserved_for_placement.has(p):
		return true

	var existing: Dictionary = reserved_for_placement[p]
	var old_klass: StringName = existing.get("klass", &"")

	# Jeśli nowa rezerwacja ma blokować ruch, a pole już jest zablokowane lub jest przejściem
	if will_block:
		if blocks_movement.has(p):
			return false
		if old_klass == &"LANE" or old_klass == &"PORTAL" or old_klass == &"CLEARANCE":
			return false

	# Tabela legalnych nakładek według klas:
	match new_klass:
		&"DECAL":
			# Ozdoby posadzkowe (gruz, kałuże, kratki) mogą leżeć na pasach ruchu i kotwicach fasady,
			# ale NIGDY na portalu ani wodzie (chyba że to kładka)
			if old_klass == &"PORTAL" or old_klass == &"LINEAR":
				return false
			return true

		&"PROP":
			# Rekwizyty fizyczne nigdy na pasie ruchu, prześwicie, portalu ani wodzie
			if old_klass == &"LANE" or old_klass == &"CLEARANCE" or old_klass == &"PORTAL" or old_klass == &"LINEAR" or old_klass == &"RAIL":
				return false
			return !blocks_movement.has(p)

		&"RAIL":
			# Barierka może stanąć tylko na brzegu kanału, nie może blokować portalu ani kładki
			if old_klass == &"PORTAL" or old_klass == &"CLEARANCE" or old_klass == &"CROSSING":
				return false
			return !blocks_movement.has(p)

		&"PORTAL":
			# Portal wymaga czystej przestrzeni bez wody, barier i rekwizytów
			if old_klass == &"LINEAR" or old_klass == &"RAIL" or blocks_movement.has(p):
				return false
			return true

		_:
			# Domyślnie brak nakładania na istniejącą rezerwację
			return false


## Eksportuje wyłącznie komórki blokujące ruch do ObjectPlan.occupancy
func export_to_occupancy(object_plan: RefCounted) -> void:
	if object_plan == null:
		return
	var occ: Dictionary = object_plan.get("occupancy") if "occupancy" in object_plan else null
	if occ != null:
		for p in blocks_movement:
			occ[p] = true
