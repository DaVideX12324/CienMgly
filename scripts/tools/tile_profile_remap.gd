@tool
extends Node2D

## Przypisywanie kafli profilu ścieków do nowej paczki — w edytorze (jak podgląd układu walki):
## otwórz scenes/tools/tile_profile_remap.tscn, zaznacz korzeń sceny.
## 1. Wybór kafla: „kafel” w inspektorze (lista: rola / wariant, stary kafel, stan) albo przeciągnij znacznik
##    „Wybor” na kafel na liście (pod podglądem). „tylko_niezatwierdzone” skraca listę w inspektorze.
## 2. Przypisanie: przeciągnij znacznik „Nowy” na kratkę atlasu po prawej (Tiles / Water / Props) albo wpisz
##    „atlas” i „nowy_kafel” w inspektorze. Przyciski: zatwierdź sugestię, następny niezatwierdzony.
## U góry podgląd zaznaczonego kafla i całego modułu (stary | nowy). Stany: auto (identyczny), ręcznie,
## sugestia (najbliższy z tabeli — do sprawdzenia). Zmiany zapisują się same do sewer_v2_remap.json;
## „Zapisz profil” generuje sewer_v2_map_tiles.tres (stary profil z podmienionymi kaflami, TileSet sewer_v2.tres).

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const OLD_PROFILE := "resources/maps/profile/sewer_map_tiles.tres"
const NEW_PROFILE := "resources/maps/profile/sewer_v2_map_tiles.tres"
const REMAP := "resources/maps/profile/sewer_v2_remap.json"
const NEW_TILESET := "resources/maps/sewer_v2.tres"
const OLD_TEX := {"Tiles": "res://assets/pixel_crawler/environments/sewer/Assets/Tiles.png",
	"Props": "res://assets/pixel_crawler/environments/sewer/Assets/Props.png"}
const NEW_TEX := {"Tiles": "res://assets/pixel_crawler/environments/sewer_v2/Assets/Tiles.png",
	"Water": "res://assets/pixel_crawler/environments/sewer_v2/Assets/Water.png",
	"Props": "res://assets/pixel_crawler/environments/sewer_v2/Assets/Props.png"}
const ATLASES: Array[String] = ["Tiles", "Water", "Props"]
const NEW_SOURCE := {"Tiles": 0, "Props": 1, "Water": 2}
const OLD_SOURCE_NAME := {0: "Tiles", 1: "Props"}
const STATUS_COLOR := {"auto": Color(0.45, 0.85, 0.5), "ręcznie": Color(0.4, 0.75, 1.0), "sugestia": Color(0.95, 0.8, 0.35), "brak": Color(0.95, 0.4, 0.4)}
const SAVE_DELAY := 0.6
const AS := 4                       # skala atlasów
const ATLAS_X := 900.0
const LIST_Y := 420.0               # początek listy kafli
const LIST_COLS := 8
const CELL := Vector2(100, 64)      # komórka listy: stary | nowy

## Zaznaczony kafel starego profilu.
@export var kafel := 0:
	set(v):
		kafel = clampi(v, 0, maxi(_entries.size() - 1, 0))
		_sync_markers()
		notify_property_list_changed()
		queue_redraw()
## Lista „kafel” w inspektorze tylko z niezatwierdzonymi (sugestia / brak) + zaznaczony.
@export var tylko_niezatwierdzone := false:
	set(v):
		tylko_niezatwierdzone = v
		notify_property_list_changed()
## Atlas nowej paczki przypisany zaznaczonemu kaflowi.
@export_enum("Tiles", "Water", "Props") var atlas := 0:
	get:
		return maxi(ATLASES.find(String(_cur().get("atlas", "Tiles"))), 0)
	set(v):
		_assign(ATLASES[v], _cur_coords())
## Kratka w atlasie (kolumna, wiersz) przypisana zaznaczonemu kaflowi.
@export var nowy_kafel := Vector2i.ZERO:
	get:
		return _cur_coords()
	set(v):
		_assign(ATLASES[atlas], v)
## Stan zaznaczonego kafla (tylko do odczytu).
@export var stan := "":
	get:
		var m := _cur()
		return "%s — %s" % [m.get("status", "-"), m.get("label", "")]
	set(v):
		pass
@export_tool_button("Zatwierdź sugestię") var _btn_accept := _accept
@export_tool_button("Następny niezatwierdzony") var _btn_next := _next_open
@export_tool_button("Zapisz profil sewer_v2_map_tiles.tres") var _btn_save := _save_profile

var _remap: Dictionary = {}         # "Tiles:x,y" -> {label, atlas, coords, status}
var _groups: Array = []             # {title, parts: [{key, offset}]}
var _entries: Array[String] = []    # klucze w kolejności listy (bez powtórzeń)
var _old_tex := {}
var _new_tex := {}
var _dirty := -1.0
var _marker_last := {}              # nazwa znacznika -> ostatnia pozycja (wykrywanie przeciągnięcia)


func _ready() -> void:
	for k in OLD_TEX:
		_old_tex[k] = load(OLD_TEX[k])
	for k in NEW_TEX:
		_new_tex[k] = load(NEW_TEX[k])
	_load_remap()
	_load_groups()
	kafel = kafel
	queue_redraw()


func _validate_property(p: Dictionary) -> void:
	match p.name:
		"kafel":
			p.hint = PROPERTY_HINT_ENUM
			var items: PackedStringArray = []
			for i in _entries.size():
				var m: Dictionary = _remap[_entries[i]]
				if tylko_niezatwierdzone and m.status not in ["sugestia", "brak"] and i != kafel:
					continue
				var txt := "%s  %s  [%s]" % [m.get("label", ""), _entries[i], m.status]
				items.append("%s:%d" % [txt.replace(":", " ").replace(",", ";"), i])
			p.hint_string = ",".join(items)
		"atlas", "nowy_kafel":
			p.usage = PROPERTY_USAGE_EDITOR
		"stan":
			p.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _load_remap() -> void:
	var f := FileAccess.open(QuizRpgPaths.path(REMAP), FileAccess.READ)
	_remap = JSON.parse_string(f.get_as_text()) if f else {}


func _key(src: int, c: Vector2i) -> String:
	return "%s:%d,%d" % [OLD_SOURCE_NAME.get(src, "Tiles"), c.x, c.y]


func _ensure(k: String, label: String) -> void:
	if not _remap.has(k):
		_remap[k] = {"label": label, "atlas": "", "coords": [0, 0], "status": "brak"}


## Grupy z profilu (rola / wariant -> części) i z mapowania (obiekty — pojedyncze kafle).
func _load_groups() -> void:
	_groups.clear()
	_entries.clear()
	var prof: MapTileProfile = load(QuizRpgPaths.path(OLD_PROFILE))
	var covered := {}
	for ts_def in prof.tilesets:
		for e: TileRoleEntry in ts_def.tile_entries:
			var rname := TileRole.name_of(e.role)
			if e.tile != null and e.tile.is_valid():
				var k0 := _key(e.tile.source_id, e.tile.atlas_coords)
				covered[k0] = true
				_ensure(k0, rname)
				_groups.append({"title": rname, "parts": [{"key": k0, "offset": Vector2i.ZERO}]})
			for v: TileVariant in e.variants:
				var parts: Array = []
				for p: TileModulePart in v.parts:
					if p == null or p.tile == null or not p.tile.is_valid():
						continue
					var k := _key(p.tile.source_id, p.tile.atlas_coords)
					parts.append({"key": k, "offset": p.offset})
					covered[k] = true
					_ensure(k, "%s/%s" % [rname, v.variant_id])
				if not parts.is_empty():
					_groups.append({"title": "%s / %s" % [rname, v.variant_id], "parts": parts})
	var objs := {}
	for k in _remap:
		if covered.has(k):
			continue
		var lab: String = _remap[k].get("label", k)
		if not objs.has(lab):
			objs[lab] = []
		(objs[lab] as Array).append({"key": k, "offset": Vector2i(objs[lab].size(), 0)})
	for lab in objs:
		_groups.append({"title": lab, "parts": objs[lab]})
	var seen := {}
	for g in _groups:
		for p in g.parts:
			if not seen.has(p.key):
				seen[p.key] = true
				_entries.append(p.key)


func _cur_key() -> String:
	return _entries[kafel] if kafel < _entries.size() else ""


func _cur() -> Dictionary:
	return _remap.get(_cur_key(), {})


func _cur_coords() -> Vector2i:
	var m := _cur()
	return Vector2i(int(m.coords[0]), int(m.coords[1])) if m.has("coords") else Vector2i.ZERO


func _assign(atlas_name: String, c: Vector2i) -> void:
	var k := _cur_key()
	if k == "" or not _new_tex.has(atlas_name):
		return
	var cells := Vector2i(_new_tex[atlas_name].get_size()) / 16
	c = c.clamp(Vector2i.ZERO, cells - Vector2i.ONE)
	var m: Dictionary = _remap[k]
	if m.atlas == atlas_name and _cur_coords() == c and m.status != "brak":
		return
	m.atlas = atlas_name
	m.coords = [c.x, c.y]
	m.status = "ręcznie"
	_dirty = SAVE_DELAY
	_sync_markers()
	notify_property_list_changed()
	queue_redraw()


func _accept() -> void:
	var m := _cur()
	if m.get("status", "") == "sugestia":
		m.status = "ręcznie"
		_dirty = SAVE_DELAY
		_next_open()


func _next_open() -> void:
	for d in range(1, _entries.size() + 1):
		var i := (kafel + d) % _entries.size()
		if _remap[_entries[i]].status in ["sugestia", "brak"]:
			kafel = i
			return


# --- geometria widoku ---

func _atlas_origin(name: String) -> Vector2:
	var y := 0.0
	for a in ATLASES:
		if a == name:
			return Vector2(ATLAS_X, y + 30)
		y += _new_tex[a].get_size().y * AS + 70
	return Vector2(ATLAS_X, 0)


func _list_pos(i: int) -> Vector2:
	return Vector2((i % LIST_COLS) * CELL.x, LIST_Y + (i / LIST_COLS) * CELL.y)


## Kratka atlasu pod punktem: [nazwa, kratka] albo [] poza atlasami.
func _atlas_at(p: Vector2) -> Array:
	for a in ATLASES:
		var o := _atlas_origin(a)
		var r := Rect2(o, _new_tex[a].get_size() * AS)
		if r.has_point(p):
			return [a, Vector2i((p - o) / (16 * AS))]
	return []


func _list_at(p: Vector2) -> int:
	if p.y < LIST_Y or p.x < 0 or p.x >= LIST_COLS * CELL.x:
		return -1
	var i := int((p.y - LIST_Y) / CELL.y) * LIST_COLS + int(p.x / CELL.x)
	return i if i < _entries.size() else -1


# --- znaczniki do przeciągania ---

func _marker(n: String) -> Marker2D:
	var m := get_node_or_null(n) as Marker2D
	if m == null and Engine.is_editor_hint() and is_inside_tree():
		m = Marker2D.new()
		m.name = n
		m.gizmo_extents = 24
		add_child(m)
		if get_tree().edited_scene_root:
			m.owner = get_tree().edited_scene_root
	return m


func _place_marker(n: String, p: Vector2) -> void:
	var m := _marker(n)
	if m:
		m.position = p
		_marker_last[n] = p


func _sync_markers() -> void:
	if _entries.is_empty() or _new_tex.is_empty():
		return
	_place_marker("Wybor", _list_pos(kafel) + CELL * 0.5)
	var m := _cur()
	if String(m.get("atlas", "")) != "":
		_place_marker("Nowy", _atlas_origin(m.atlas) + (Vector2(_cur_coords()) + Vector2(0.5, 0.5)) * 16 * AS)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or _entries.is_empty():
		return
	var w := _marker("Wybor")
	if w and w.position != _marker_last.get("Wybor", w.position):
		_marker_last["Wybor"] = w.position
		var i := _list_at(w.position)
		if i >= 0 and i != kafel:
			kafel = i
	var n := _marker("Nowy")
	if n and n.position != _marker_last.get("Nowy", n.position):
		_marker_last["Nowy"] = n.position
		var hit := _atlas_at(n.position)
		if not hit.is_empty():
			_assign(hit[0], hit[1])
	if _dirty >= 0.0:
		_dirty -= delta
		if _dirty < 0.0:
			_save_remap()


func _save_remap() -> void:
	var f := FileAccess.open(QuizRpgPaths.path(REMAP), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_remap, " "))


func _save_profile() -> void:
	_save_remap()
	var prof: MapTileProfile = (load(QuizRpgPaths.path(OLD_PROFILE)) as MapTileProfile).duplicate(true)
	var ts: TileSet = load(QuizRpgPaths.path(NEW_TILESET))
	var missing := 0
	for ts_def in prof.tilesets:
		ts_def.tile_set = ts
		for e: TileRoleEntry in ts_def.tile_entries:
			var refs: Array = []
			if e.tile != null and e.tile.is_valid():
				refs.append(e)
			for v: TileVariant in e.variants:
				for p: TileModulePart in v.parts:
					if p != null and p.tile != null and p.tile.is_valid():
						refs.append(p)
			for holder in refs:
				var t: TileRef = holder.tile
				var m: Dictionary = _remap.get(_key(t.source_id, t.atlas_coords), {})
				if String(m.get("atlas", "")) == "":
					missing += 1
					continue
				# alternatywy (np. brzegi bez kolizji pod kładką) dojdą razem z kolizjami w sewer_v2.tres
				holder.tile = TileRef.make(Vector2i(int(m.coords[0]), int(m.coords[1])), NEW_SOURCE[m.atlas], 0)
	var err := ResourceSaver.save(prof, QuizRpgPaths.path(NEW_PROFILE))
	var open := 0
	for k in _remap:
		if _remap[k].status in ["sugestia", "brak"]:
			open += 1
	print("tile_profile_remap: zapisano %s (błąd %d); niezatwierdzone %d, bez przypisania %d" % [NEW_PROFILE, err, open, missing])


# --- rysowanie ---

func _draw_tile(key: String, new: bool, r: Rect2) -> void:
	if new:
		var m: Dictionary = _remap.get(key, {})
		if String(m.get("atlas", "")) == "":
			return
		draw_texture_rect_region(_new_tex[m.atlas], r, Rect2(int(m.coords[0]) * 16, int(m.coords[1]) * 16, 16, 16))
	else:
		var p := key.split(":")
		var xy := p[1].split(",")
		draw_texture_rect_region(_old_tex[p[0]], r, Rect2(int(xy[0]) * 16, int(xy[1]) * 16, 16, 16))


func _text(p: Vector2, s: String, size := 16, col := Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	if _entries.is_empty() or _new_tex.is_empty():
		return
	var key := _cur_key()
	var m := _cur()
	var col: Color = STATUS_COLOR.get(m.get("status", ""), Color.WHITE)
	draw_rect(Rect2(-20, -20, ATLAS_X - 20, LIST_Y - 10), Color(0.12, 0.12, 0.15))
	_text(Vector2(0, 10), "%s   %s   [%s]" % [m.get("label", ""), key, m.get("status", "")], 22, col)
	# zaznaczony kafel: stary -> nowy
	draw_rect(Rect2(0, 30, 128, 128), Color(0.22, 0.22, 0.27))
	_draw_tile(key, false, Rect2(0, 30, 128, 128))
	_text(Vector2(140, 100), "→", 32)
	draw_rect(Rect2(180, 30, 128, 128), Color(0.22, 0.22, 0.27))
	_draw_tile(key, true, Rect2(180, 30, 128, 128))
	_text(Vector2(0, 180), "stary", 14, Color(0.7, 0.7, 0.7))
	_text(Vector2(180, 180), "nowy: %s (%d, %d)" % [m.get("atlas", "—"), _cur_coords().x, _cur_coords().y], 14, Color(0.7, 0.7, 0.7))
	# moduły, w których kafel występuje: stary | nowy
	var x := 340.0
	for g in _groups:
		var has := false
		for p in g.parts:
			if p.key == key:
				has = true
		if not has:
			continue
		var b := _module_bounds(g.parts)
		var s := mini(64, int(200.0 / maxi(b.size.y, 1)))
		var w := b.size.x * s
		if x + w * 2 + 20 > ATLAS_X - 40:
			break
		_text(Vector2(x, 30), g.title, 13, Color(0.8, 0.8, 0.8))
		for side in 2:
			var x0: float = x + side * (w + 10)
			draw_rect(Rect2(x0, 40, w, b.size.y * s), Color(0.22, 0.22, 0.27))
			for p in g.parts:
				var o: Vector2i = p.offset - b.position
				var r := Rect2(x0 + o.x * s, 40 + o.y * s, s, s)
				_draw_tile(p.key, side == 1, r)
				if p.key == key:
					draw_rect(r, col, false, 2.0)
		x += w * 2 + 40
	_text(Vector2(0, LIST_Y - 40), "Wszystkie kafle (stary | nowy) — przeciągnij znacznik „Wybor”, żeby zaznaczyć", 16, Color(0.8, 0.8, 0.8))
	for i in _entries.size():
		var p := _list_pos(i)
		var mm: Dictionary = _remap[_entries[i]]
		var c: Color = STATUS_COLOR.get(mm.status, Color.WHITE)
		draw_rect(Rect2(p, CELL - Vector2(4, 4)), Color(c, 0.18) if i != kafel else Color(0.3, 0.38, 0.6))
		_draw_tile(_entries[i], false, Rect2(p + Vector2(6, 8), Vector2(40, 40)))
		_draw_tile(_entries[i], true, Rect2(p + Vector2(52, 8), Vector2(40, 40)))
		draw_rect(Rect2(p, CELL - Vector2(4, 4)), c if i != kafel else Color.WHITE, false, 2.0 if i != kafel else 4.0)
	# atlasy nowej paczki
	for a in ATLASES:
		var tex: Texture2D = _new_tex[a]
		var o := _atlas_origin(a)
		var sz := tex.get_size() * AS
		_text(o + Vector2(0, -8), "%s (przeciągnij znacznik „Nowy” na kratkę)" % a, 22)
		draw_rect(Rect2(o, sz), Color(0.18, 0.18, 0.22))
		draw_texture_rect(tex, Rect2(o, sz), false)
		var cells := Vector2i(tex.get_size()) / 16
		for cx in range(cells.x + 1):
			draw_line(o + Vector2(cx * 16 * AS, 0), o + Vector2(cx * 16 * AS, sz.y), Color(1, 0, 1, 0.3))
		for cy in range(cells.y + 1):
			draw_line(o + Vector2(0, cy * 16 * AS), o + Vector2(sz.x, cy * 16 * AS), Color(1, 0, 1, 0.3))
		for cx in cells.x:
			_text(o + Vector2(cx * 16 * AS + 2, sz.y + 14), str(cx), 12, Color(0.6, 0.6, 0.6))
		for cy in cells.y:
			_text(o + Vector2(-22, cy * 16 * AS + 14), str(cy), 12, Color(0.6, 0.6, 0.6))
		for k in _remap:
			var mm: Dictionary = _remap[k]
			if mm.atlas != a:
				continue
			var r := Rect2(o + Vector2(int(mm.coords[0]), int(mm.coords[1])) * 16 * AS, Vector2.ONE * 16 * AS)
			draw_rect(r, Color(STATUS_COLOR.get(mm.status, Color.WHITE), 0.2))
			if k == key:
				draw_rect(r, Color.WHITE, false, 4.0)


func _module_bounds(parts: Array) -> Rect2i:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := -mn
	for p in parts:
		var o: Vector2i = p.offset
		mn = Vector2i(mini(mn.x, o.x), mini(mn.y, o.y))
		mx = Vector2i(maxi(mx.x, o.x), maxi(mx.y, o.y))
	return Rect2i(mn, mx - mn + Vector2i.ONE)
