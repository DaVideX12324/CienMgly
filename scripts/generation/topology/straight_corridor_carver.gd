class_name StraightCorridorCarver
extends "corridor_carver.gd"

## Korytarze o prostych ścianach, stała szerokość (wnętrza typu ścieki).
## corridor_shape = "straight": L z dwóch odcinków osiowych.
## Flagi corridor_diagonal_45 / corridor_diagonal_30_60: część korytarzy ma odcinek skośny o stałym
## kącie — regularny schodek (poziomo:pionowo) 1:1 (45°) albo 2:1 / 1:2 (~30° / ~60°); resztę
## przesunięcia pokrywa odcinek osiowy przed albo za skosem. Losowanie z ctx.rng.

const STEP_45: Array[Vector2i] = [Vector2i(1, 1)]
const STEP_30_60: Array[Vector2i] = [Vector2i(2, 1), Vector2i(1, 2)]
## Minimalna liczba kroków skosu (krótszy skos = zwykłe L).
const MIN_DIAGONAL_STEPS := 3

var diagonal_45 := false
var diagonal_30_60 := false


func carve(ctx: GenerationContext, from: Vector2i, to: Vector2i, width: int) -> void:
	var w := maxi(width, 1)
	if (diagonal_45 or diagonal_30_60) and ctx.rng.randi() % 3 != 0 and _carve_diagonal(ctx, from, to, w):
		return
	var corner := Vector2i(to.x, from.y) if ctx.rng.randi() % 2 == 0 else Vector2i(from.x, to.y)
	_carve_band(ctx, from, corner, w)
	_carve_band(ctx, corner, to, w)


## Skos o losowym dopuszczalnym kącie + odcinek osiowy. false = żaden kąt nie pasuje.
func _carve_diagonal(ctx: GenerationContext, from: Vector2i, to: Vector2i, w: int) -> bool:
	var d := to - from
	var allowed: Array[Vector2i] = []
	if diagonal_45:
		allowed.append_array(STEP_45)
	if diagonal_30_60:
		allowed.append_array(STEP_30_60)
	var options: Array[Vector2i] = []
	for st in allowed:
		if mini(absi(d.x) / st.x, absi(d.y) / st.y) >= MIN_DIAGONAL_STEPS:
			options.append(st)
	if options.is_empty():
		return false
	var st := options[ctx.rng.randi() % options.size()]
	var steps := mini(absi(d.x) / st.x, absi(d.y) / st.y)
	var sx := signi(d.x)
	var sy := signi(d.y)
	var diag := Vector2i(sx * st.x * steps, sy * st.y * steps)
	# Odcinek osiowy przed albo za skosem.
	if ctx.rng.randi() % 2 == 0:
		var mid := to - diag
		_carve_band(ctx, from, mid, w)
		_carve_stairs(ctx, mid, st, sx, sy, steps, w)
	else:
		_carve_stairs(ctx, from, st, sx, sy, steps, w)
		_carve_band(ctx, from + diag, to, w)
	return true


## Schodek: steps powtórzeń (st.x kratek w poziomie, potem st.y w pionie), w każdej kratce
## kwadrat w×w — brzegi korytarza są regularnymi schodkami o stałym kącie.
static func _carve_stairs(ctx: GenerationContext, start: Vector2i, st: Vector2i, sx: int, sy: int, steps: int, w: int) -> void:
	var p := start
	_carve_band(ctx, p, p, w)
	for i in steps:
		for k in st.x:
			p.x += sx
			_carve_band(ctx, p, p, w)
		for k in st.y:
			p.y += sy
			_carve_band(ctx, p, p, w)


## Prostokąt podłogi wzdłuż odcinka osiowego a-b; szerokość w po obu stronach osi
## (przy parzystej szerokości dodatkowa kratka w stronę +x / +y).
static func _carve_band(ctx: GenerationContext, a: Vector2i, b: Vector2i, w: int) -> void:
	var lo := (w - 1) / 2
	var hi := w - 1 - lo
	var x0 := maxi(mini(a.x, b.x) - lo, 1)
	var y0 := maxi(mini(a.y, b.y) - lo, 1)
	var x1 := mini(maxi(a.x, b.x) + hi, ctx.width - 2)
	var y1 := mini(maxi(a.y, b.y) + hi, ctx.height - 2)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			ctx.grid[Vector2i(x, y)] = CellType.FLOOR
