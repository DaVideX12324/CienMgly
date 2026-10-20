class_name NicheContentPlanner
extends RefCounted

## Zawartość nisz out (sekretnych, NichePlacer) — po planie kafli, bo nisze powstają dopiero przy fasadach. Każda nisza
## losuje rodzaj z wag "niche_content.weights" w JSON mapy: przedmiot na ziemi (GroundItem) albo skrzynia; tier i łup
## skrzyni nisz, łup przedmiotu — ProceduralLevel (_apply_niche_content). Rodzaje jeszcze niezrobione (sekretny pokój)
## wypadają z losowania — wagi reszty liczą się proporcjonalnie, więc każda nisza ma zawartość.
## Obiekt stoi w głębi niszy (między kolumnami pary, nad rzędem stopy); gracz sięga go z podłogi przed niszą.
## Deterministycznie: RNG z hash(seed mapy, kratka niszy).

const QuizRpgPaths = preload("../../quiz_rpg_paths.gd")

const KINDS := {&"item": &"niche_item", &"chest": &"niche_chest"}
const ITEM_SCENE := "scenes/objects/ground_item.tscn"
## Przesunięcie punktu obiektu względem środka dołu kratki kotwicy (lewa kolumna, rząd stopy): x na granicę kolumn,
## y w głąb niszy (px).
const OFFSET := Vector2(8, -14)
## Rzędy podłogi przed niszą (od rzędu stopy w dół) bez innych obiektów.
const CLEAR_ROWS := 2


static func plan(result, cfg: Dictionary) -> void:
	if cfg.is_empty() or result.objects == null or result.out_niches.is_empty():
		return
	var weights: Dictionary = cfg.get("weights", {})
	var objs: ObjectPlan = result.objects
	var defs := {}
	var front := {}   # idx kratki przed niszą z zawartością -> true
	var added: Array[ObjectPlacement] = []
	for c: Vector2i in result.out_niches:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([result.seed_used, "niche", c.x, c.y])
		var kind := _pick_kind(weights, rng)
		if kind == &"" or not _front_ok(objs, c):
			continue
		if not defs.has(kind):
			defs[kind] = _def(kind)
		var pl := ObjectPlacement.new()
		pl.def = defs[kind]
		pl.cell = c
		pl.offset = OFFSET
		added.append(pl)
		objs.stats[pl.def.id] = int(objs.stats.get(pl.def.id, 0)) + 1
		for dy in CLEAR_ROWS:
			for dx in 2:
				if c.y + dy < objs.height:
					front[(c.y + dy) * objs.width + c.x + dx] = true
	if added.is_empty():
		return
	# Przed niszą (CLEAR_ROWS rzędów) bez innych obiektów (kamień, grzyb zasłaniały zawartość albo dojście). Zdjęcie przeszkody z kolizją tylko
	# poszerza przejścia — siatkę nawigacji liczy się później.
	var kept: Array[ObjectPlacement] = []
	for pl in objs.placements:
		var hit := pl.def.klass != ObjectDef.Klass.INTERACTIVE and front.has(pl.cell.y * objs.width + pl.cell.x)
		if not hit and pl.def.klass != ObjectDef.Klass.INTERACTIVE:
			for j in pl.cells:
				if front.has(j):
					hit = true
					break
		if hit:
			objs.stats[pl.def.id] = int(objs.stats.get(pl.def.id, 1)) - 1
			for j in pl.cells:
				objs.occupancy[j] &= ~(ObjectPlan.USED | ObjectPlan.SOLID)
		else:
			kept.append(pl)
	kept.append_array(added)
	objs.placements = kept


## Rodzaj z wag (tylko zrobione rodzaje); &"" gdy żadna waga > 0.
static func _pick_kind(weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total := 0.0
	for k in KINDS:
		total += maxf(float(weights.get(String(k), 0.0)), 0.0)
	if total <= 0.0:
		return &""
	var roll := rng.randf() * total
	for k in KINDS:
		roll -= maxf(float(weights.get(String(k), 0.0)), 0.0)
		if roll < 0.0:
			return k
	return KINDS.keys()[-1]


## Kratki przed niszą (obie kolumny, rząd stopy) w mapie i bez obiektu interaktywnego (skrzynia, dźwignia) — ten zostaje,
## a nisza pusta.
static func _front_ok(objs: ObjectPlan, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x + 1 >= objs.width or c.y >= objs.height:
		return false
	var i := c.y * objs.width + c.x
	for pl in objs.placements:
		if pl.def.klass == ObjectDef.Klass.INTERACTIVE and (pl.cells.has(i) or pl.cells.has(i + 1)):
			return false
	return true


static func _def(kind: StringName) -> ObjectDef:
	var d := ObjectDef.new()
	d.id = KINDS[kind]
	d.klass = ObjectDef.Klass.INTERACTIVE
	d.scene = "chest" if kind == &"chest" else QuizRpgPaths.path(ITEM_SCENE)
	d.footprint.assign([Vector2i.ZERO])
	return d
