class_name NicheContentPlanner
extends RefCounted

## Zawartość nisz out (sekretnych, NichePlacer) — po planie kafli, bo nisze powstają dopiero przy fasadach. Każda nisza
## losuje rodzaj z wag "niche_content.weights" w JSON mapy: przedmiot na ziemi (GroundItem), skrzynia albo przejście do
## sekretnego pokoju (SecretPassage — osobna mapa, "secret_scene"); tier i łup skrzyni nisz, łup przedmiotu, cel przejścia —
## ProceduralLevel (_apply_niche_content). Rodzaj bez wagi (> 0) wypada z losowania — reszta proporcjonalnie.
## Pokój relikwii ("niche_content.relic_scene", decyzja usera 2026-10-21): dokładnie jedna nisza na mapę prowadzi zamiast
## losowania do osobnej mapy z relikwią (2–3 pokoje, relikwia w ostatnim, boss przed nim) — wybrana z hash(seed mapy)
## spośród nisz dalszych od wejścia niż mediana (po podłodze). Niszę out na takiej mapie gwarantuje plan kafli
## (CaveGenerator.plan_cave_tiles, force_out_niche).
## Obiekt stoi w głębi niszy (między kolumnami pary, nad rzędem stopy); gracz sięga go z podłogi przed niszą.
## Deterministycznie: RNG z hash(seed mapy, kratka niszy).

const QuizRpgPaths = preload("../../quiz_rpg_paths.gd")

const KINDS := {&"item": &"niche_item", &"chest": &"niche_chest", &"secret_room": &"niche_secret"}
const RELIC_ID := &"niche_relic"
const ITEM_SCENE := "scenes/objects/ground_item.tscn"
const PASSAGE_SCENE := "scenes/objects/secret_passage.tscn"
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Przesunięcie punktu obiektu względem środka dołu kratki kotwicy (lewa kolumna, rząd stopy): x na granicę kolumn,
## y w głąb niszy (px).
const OFFSET := Vector2(8, -14)
## Rzędy podłogi przed niszą (od rzędu stopy w dół) bez innych obiektów.
const CLEAR_ROWS := 2


static func plan(result, cfg: Dictionary) -> void:
	if cfg.is_empty() or result.objects == null or result.out_niches.is_empty():
		return
	var weights: Dictionary = (cfg.get("weights", {}) as Dictionary).duplicate()
	if str(cfg.get("secret_scene", "")).is_empty():
		weights.erase("secret_room")  # bez sceny sekretnego pokoju nie ma dokąd prowadzić
	var objs: ObjectPlan = result.objects
	var defs := {}
	var front := {}   # idx kratki przed niszą z zawartością -> true
	var added: Array[ObjectPlacement] = []
	var relic := _relic_niche(result, objs) if has_relic_room(cfg) else Vector2i(-1, -1)
	for c: Vector2i in result.out_niches:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([result.seed_used, "niche", c.x, c.y])
		var kind := _pick_kind(weights, rng)
		if c == relic:
			kind = RELIC_ID
		elif kind == &"" or not _front_ok(objs, c):
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


## Czy mapa ma pokój relikwii (scena w "relic_scene") — wtedy zawsze dokładnie jedna nisza do niego.
static func has_relic_room(cfg: Dictionary) -> bool:
	return not str(cfg.get("relic_scene", "")).is_empty()


## Nisza relikwii: spośród nisz z wolnym frontem (gdy żadnej — spośród wszystkich) te nie bliżej wejścia (po podłodze)
## niż mediana, jedna z hash(seed mapy). (-1, -1) = brak nisz.
static func _relic_niche(result, objs: ObjectPlan) -> Vector2i:
	var pool: Array[Vector2i] = []
	for c: Vector2i in result.out_niches:
		if _front_ok(objs, c):
			pool.append(c)
	if pool.is_empty():
		pool.assign(result.out_niches)
	if pool.is_empty():
		return Vector2i(-1, -1)
	var dist := {result.entrance_pos: 0}
	var queue: Array[Vector2i] = [result.entrance_pos]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d in DIRS4:
			var n := p + d
			if not dist.has(n) and GridUtils.is_walkable(result.grid, n):
				dist[n] = int(dist[p]) + 1
				queue.append(n)
	pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := int(dist.get(a, -1))
		var db := int(dist.get(b, -1))
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var far := pool.slice(pool.size() / 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([result.seed_used, "relic"])
	return far[rng.randi() % far.size()]


## Rodzaj z wag (tylko znane rodzaje); &"" gdy żadna waga > 0.
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
	d.id = KINDS.get(kind, kind)
	d.klass = ObjectDef.Klass.INTERACTIVE
	match kind:
		&"chest": d.scene = "chest"
		&"secret_room", RELIC_ID: d.scene = QuizRpgPaths.path(PASSAGE_SCENE)
		_: d.scene = QuizRpgPaths.path(ITEM_SCENE)
	d.footprint.assign([Vector2i.ZERO])
	return d
