@tool
extends Node2D

## Edytor przypisań kafli profilu (MapTileProfile .tres) — w edytorze, jak podgląd układu walki:
## otwórz scenes/tools/tile_profile_editor.tscn, zaznacz korzeń sceny.
## 1. Profil: przeciągnij plik profilu do „profile” albo utwórz nowy (grupa „Nowy profil”: TileSet + ścieżka
##    pliku -> „Utwórz profil”). Profil z kilkoma zestawami — „zestaw”.
## 2. Widok: po lewej wszystkie role (rola / wariant), każda narysowana obecnymi kaflami w układzie części;
##    czerwona kratka = część bez kafla, szara kreskowana = „wymaż”. Po prawej atlasy TileSetu zestawu
##    (kratki użyte w profilu podświetlone, wybrana — biała ramka).
## 3. Wybór części: „miejsce” w inspektorze albo przeciągnij znacznik „Wybor” na część na liście.
## 4. Przypisanie: przeciągnij znacznik „Kafel” na kratkę atlasu albo pola „zrodlo” / „kafel” / „alternatywa”.
##    Warstwa i przesunięcie części, waga wariantu — też w inspektorze.
## 5. Struktura: dodaj / usuń część, wariant, rolę (grupa „Role”; „Dodaj brakujące role” wstawia wszystkie
##    role enuma, których profil nie ma — z jedną pustą częścią).
## Zmiany zapisują się same do pliku profilu (po chwili bez zmian). Bez cofania (Ctrl+Z) — w razie czego git.

const SAVE_DELAY := 0.6
const AS := 4                       # skala atlasów
const LIST_W := 1100.0              # szerokość kolumny ról
const LIST_Y := 330.0               # początek listy ról (nad nią podgląd zaznaczonego)
const PS := 32                      # bok kratki części na liście
const ATLAS_X := LIST_W + 120.0
const COL_EMPTY := Color(0.9, 0.3, 0.3)
const COL_SEL := Color(1, 1, 1)
const COL_USED := Color(0.35, 0.7, 1.0)

## Edytowany profil (plik .tres).
@export var profile: MapTileProfile:
	set(v):
		profile = v
		_rebuild()
## Zestaw profilu (NamedTileSetDefinition), gdy jest ich kilka.
@export var zestaw := 0:
	set(v):
		zestaw = v
		_rebuild()

@export_group("Nowy profil")
## TileSet nowego profilu (źródła atlasów).
@export var nowy_tileset: TileSet
## Ścieżka nowego pliku profilu, np. res://modules/quiz_rpg/resources/maps/profile/nowy_map_tiles.tres.
@export_file("*.tres") var nowy_plik := ""
@export_tool_button("Utwórz profil") var _b_create := _create_profile

@export_group("Część")
## Zaznaczona część (rola / wariant / przesunięcie / warstwa / kafel).
@export var miejsce := 0:
	set(v):
		miejsce = clampi(v, 0, maxi(_slots.size() - 1, 0))
		_sync_markers()
		notify_property_list_changed()
		queue_redraw()
## Lista „miejsce” tylko z częściami bez kafla (+ zaznaczona).
@export var tylko_puste := false:
	set(v):
		tylko_puste = v
		notify_property_list_changed()
## Źródło atlasu (source_id) kafla zaznaczonej części.
@export var zrodlo := 0:
	get:
		var t := _cur_tile()
		return t.source_id if t else (_sources[0].id if not _sources.is_empty() else 0)
	set(v):
		_set_tile(v, _cur_coords(), 0)
## Kratka atlasu (kolumna, wiersz) kafla zaznaczonej części.
@export var kafel := Vector2i.ZERO:
	get:
		return _cur_coords()
	set(v):
		_set_tile(zrodlo, v, alternatywa)
## Alternatywa kafla (np. wersja bez kolizji).
@export var alternatywa := 0:
	get:
		var t := _cur_tile()
		return t.alternative_tile if t else 0
	set(v):
		_set_tile(zrodlo, _cur_coords(), v)
## Warstwa docelowa części (Walls, Floor, FloorDecor…).
@export var warstwa := &"Walls":
	get:
		var p := _cur_part()
		return p.layer if p else &""
	set(v):
		var p := _cur_part()
		if p and p.layer != v:
			p.layer = v
			_touch(false)
## Przesunięcie części względem kotwicy modułu.
@export var przesuniecie := Vector2i.ZERO:
	get:
		var p := _cur_part()
		return p.offset if p else Vector2i.ZERO
	set(v):
		var p := _cur_part()
		if p and p.offset != v:
			p.offset = v
			_touch(true)
## Waga losowania wariantu.
@export var waga := 1.0:
	get:
		var s := _cur()
		return (s.variant as TileVariant).weight if s and s.variant else 1.0
	set(v):
		var s := _cur()
		if s and s.variant and (s.variant as TileVariant).weight != v:
			(s.variant as TileVariant).weight = v
			_touch(false)
@export_tool_button("Następna pusta") var _b_next := _next_empty
@export_tool_button("Ustaw: wymaż kratkę") var _b_erase := _set_erase
@export_tool_button("Wyczyść kafel") var _b_clear := _clear_tile
@export_tool_button("Dodaj część (pod spodem)") var _b_add_part := _add_part
@export_tool_button("Usuń część") var _b_del_part := _del_part
@export_tool_button("Dodaj wariant") var _b_add_var := _add_variant
@export_tool_button("Usuń wariant") var _b_del_var := _del_variant

@export_group("Role")
## Rola do dodania przyciskiem „Dodaj rolę”.
@export var nowa_rola: TileRole.Id = TileRole.Id.NONE
@export_tool_button("Dodaj rolę") var _b_add_role := _add_role
@export_tool_button("Dodaj brakujące role") var _b_add_missing := _add_missing_roles
@export_tool_button("Usuń rolę zaznaczonej części") var _b_del_role := _del_role

var _slots: Array = []              # {entry, variant, part, holder, group}
var _groups: Array = []             # {entry, variant, title, slots: [indeksy], rect}
var _slot_rects: Array[Rect2] = []
var _sources: Array = []            # {id, src: TileSetAtlasSource, name, origin}
var _dirty := -1.0
var _marker_last := {}


func _ready() -> void:
	_rebuild()


# Skrypty zasobów profilu (TileRef, TileRoleEntry…) nie są @tool — w edytorze to atrapy (placeholder):
# pola działają, metody nie. Stąd własne odpowiedniki is_valid / is_erase / make / get_entry / name_of.
static func _valid(t: TileRef) -> bool:
	return t != null and t.source_id >= 0 and t.atlas_coords.x >= 0 and t.atlas_coords.y >= 0


static func _erase(t: TileRef) -> bool:
	return t != null and t.atlas_coords == Vector2i(-1, -1)


static func _ref(c: Vector2i, sid: int, alt: int) -> TileRef:
	var r := TileRef.new()
	r.source_id = sid
	r.atlas_coords = c
	r.alternative_tile = alt
	return r


static func _entry(d: NamedTileSetDefinition, role: int) -> TileRoleEntry:
	for e: TileRoleEntry in d.tile_entries:
		if e != null and e.role == role:
			return e
	return null


static func _role_name(role: int) -> String:
	var keys := TileRole.Id.keys()
	return keys[role] if role >= 0 and role < keys.size() else "UNKNOWN(%d)" % role


func _def() -> NamedTileSetDefinition:
	if profile == null or profile.tilesets.is_empty():
		return null
	return profile.tilesets[clampi(zestaw, 0, profile.tilesets.size() - 1)]


# --- dane ---

func _rebuild() -> void:
	_slots.clear()
	_groups.clear()
	_sources.clear()
	var d := _def()
	if d:
		for e: TileRoleEntry in d.tile_entries:
			if e == null:
				continue
			var rname := _role_name(e.role)
			if e.variants.is_empty():
				_add_group(e, null, rname, [null])
				continue
			for v: TileVariant in e.variants:
				_add_group(e, v, "%s / %s" % [rname, v.variant_id], v.parts if not v.parts.is_empty() else [null])
		if d.tile_set:
			var y := 30.0
			for i in d.tile_set.get_source_count():
				var sid := d.tile_set.get_source_id(i)
				var src := d.tile_set.get_source(sid) as TileSetAtlasSource
				if src == null or src.texture == null:
					continue
				var nm := src.texture.resource_path.get_file().get_basename()
				_sources.append({"id": sid, "src": src, "name": nm, "origin": Vector2(ATLAS_X, y)})
				y += src.texture.get_size().y * AS + 80
	_layout()
	miejsce = miejsce
	notify_property_list_changed()
	queue_redraw()


func _add_group(e: TileRoleEntry, v: TileVariant, title: String, parts: Array) -> void:
	var g := {"entry": e, "variant": v, "title": title, "slots": []}
	for p in parts:
		(g.slots as Array).append(_slots.size())
		_slots.append({"entry": e, "variant": v, "part": p, "holder": p if p else e, "group": _groups.size()})
	_groups.append(g)


## Rozmieszczenie ról na liście (przepływ wierszami) -> prostokąty części.
func _layout() -> void:
	_slot_rects.resize(_slots.size())
	var font := ThemeDB.fallback_font
	var x := 0.0
	var y := LIST_Y
	var row_h := 0.0
	for g in _groups:
		var b := _bounds(g.slots)
		var w: float = maxf(b.size.x * PS, font.get_string_size(g.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 16
		var h: float = 22 + b.size.y * PS + 10
		if x > 0 and x + w > LIST_W:
			x = 0
			y += row_h + 8
			row_h = 0
		g.rect = Rect2(x, y, w, h)
		for si in g.slots:
			var o := _offset(si) - b.position
			_slot_rects[si] = Rect2(x + 8 + o.x * PS, y + 22 + o.y * PS, PS, PS)
		x += w + 8
		row_h = maxf(row_h, h)


func _offset(si: int) -> Vector2i:
	var p = _slots[si].part
	return (p as TileModulePart).offset if p else Vector2i.ZERO


func _bounds(slot_ids: Array) -> Rect2i:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := -mn
	for si in slot_ids:
		var o := _offset(si)
		mn = Vector2i(mini(mn.x, o.x), mini(mn.y, o.y))
		mx = Vector2i(maxi(mx.x, o.x), maxi(mx.y, o.y))
	return Rect2i(mn, mx - mn + Vector2i.ONE)


func _cur() -> Dictionary:
	return _slots[miejsce] if miejsce < _slots.size() else {}


func _cur_part() -> TileModulePart:
	var s := _cur()
	return s.part if s else null


func _cur_tile() -> TileRef:
	var s := _cur()
	return s.holder.tile if s else null


func _cur_coords() -> Vector2i:
	var t := _cur_tile()
	return t.atlas_coords if _valid(t) else Vector2i.ZERO


func _source(sid: int) -> Dictionary:
	for s in _sources:
		if s.id == sid:
			return s
	return {}


## Zmiana zapisu: struktura (przebudowa listy) albo tylko wartości.
func _touch(structure: bool) -> void:
	_dirty = SAVE_DELAY
	if structure:
		_rebuild()
	else:
		_sync_markers()
		notify_property_list_changed()
		queue_redraw()


func _set_tile(sid: int, c: Vector2i, alt: int) -> void:
	var s := _cur()
	if s.is_empty():
		return
	var src := _source(sid)
	if not src.is_empty():
		c = c.clamp(Vector2i.ZERO, (src.src as TileSetAtlasSource).get_atlas_grid_size() - Vector2i.ONE)
	var t: TileRef = s.holder.tile
	if t and t.source_id == sid and t.atlas_coords == c and t.alternative_tile == alt:
		return
	if s.part == null and s.variant == null and (s.entry as TileRoleEntry).tile == null:
		# rola bez wariantów i bez kafla: nowy model — wariant A z jedną częścią
		_new_variant(s.entry, Vector2i.ZERO)
		_rebuild()
		s = _cur()
	s.holder.tile = _ref(c, sid, alt)
	_touch(false)


func _set_erase() -> void:
	var s := _cur()
	if s and s.part:
		s.part.tile = _ref(Vector2i(-1, -1), zrodlo, 0)
		_touch(false)


func _clear_tile() -> void:
	var s := _cur()
	if s:
		s.holder.tile = null
		_touch(false)


func _next_empty() -> void:
	for d in range(1, _slots.size() + 1):
		var i := (miejsce + d) % _slots.size()
		var t: TileRef = _slots[i].holder.tile
		if t == null:
			miejsce = i
			return


func _new_variant(e: TileRoleEntry, off: Vector2i) -> TileVariant:
	var v := TileVariant.new()
	v.variant_id = StringName(String.chr(65 + e.variants.size())) if e.variants.size() < 26 else StringName("V%d" % e.variants.size())
	var p := TileModulePart.new()
	p.offset = off
	v.parts.append(p)
	e.variants.append(v)
	return v


func _select_where(part: TileModulePart, e: TileRoleEntry) -> void:
	for i in _slots.size():
		if (part and _slots[i].part == part) or (part == null and _slots[i].entry == e):
			miejsce = i
			return


func _add_part() -> void:
	var s := _cur()
	if s.is_empty() or s.variant == null:
		return
	var v: TileVariant = s.variant
	var b := _bounds(_groups[s.group].slots)
	var p := TileModulePart.new()
	p.offset = Vector2i(b.position.x, b.end.y)
	p.layer = s.part.layer if s.part else &"Walls"
	v.parts.append(p)
	_touch(true)
	_select_where(p, null)


func _del_part() -> void:
	var s := _cur()
	if s.is_empty() or s.part == null or (s.variant as TileVariant).parts.size() <= 1:
		return
	(s.variant as TileVariant).parts.erase(s.part)
	_touch(true)
	miejsce = maxi(miejsce - 1, 0)


func _add_variant() -> void:
	var s := _cur()
	if s.is_empty():
		return
	var v := _new_variant(s.entry, Vector2i.ZERO)
	_touch(true)
	_select_where(v.parts[0], null)


func _del_variant() -> void:
	var s := _cur()
	if s.is_empty() or s.variant == null:
		return
	(s.entry as TileRoleEntry).variants.erase(s.variant)
	_touch(true)
	miejsce = maxi(miejsce - 1, 0)


func _add_role() -> void:
	var d := _def()
	if d == null or nowa_rola == TileRole.Id.NONE:
		return
	var e := _entry(d, nowa_rola)
	if e == null:
		e = TileRoleEntry.new()
		e.role = nowa_rola
		_new_variant(e, Vector2i.ZERO)
		d.tile_entries.append(e)
		_touch(true)
	_select_where(null, e)


func _add_missing_roles() -> void:
	var d := _def()
	if d == null:
		return
	for r in TileRole.Id.values():
		if r != TileRole.Id.NONE and _entry(d, r) == null:
			var e := TileRoleEntry.new()
			e.role = r
			_new_variant(e, Vector2i.ZERO)
			d.tile_entries.append(e)
	_touch(true)


func _del_role() -> void:
	var s := _cur()
	var d := _def()
	if s.is_empty() or d == null:
		return
	d.tile_entries.erase(s.entry)
	_touch(true)


func _create_profile() -> void:
	if nowy_tileset == null or nowy_plik == "":
		push_warning("tile_profile_editor: ustaw „nowy_tileset” i „nowy_plik”.")
		return
	var d := NamedTileSetDefinition.new()
	d.id = StringName(nowy_plik.get_file().get_basename().trim_suffix("_map_tiles"))
	d.display_name = String(d.id).capitalize()
	d.tile_set = nowy_tileset
	var p := MapTileProfile.new()
	p.tilesets.append(d)
	p.default_tileset_id = d.id
	var err := ResourceSaver.save(p, nowy_plik)
	if err != OK:
		push_warning("tile_profile_editor: zapis %s nie powiódł się (%d)." % [nowy_plik, err])
		return
	p.take_over_path(nowy_plik)
	zestaw = 0
	profile = p
	print("tile_profile_editor: utworzono %s" % nowy_plik)


func _save() -> void:
	if profile == null:
		return
	var path := profile.resource_path
	if path == "" or path.contains("::"):
		if nowy_plik == "":
			push_warning("tile_profile_editor: profil bez pliku — ustaw „nowy_plik”, żeby zapisać.")
			return
		path = nowy_plik
		profile.take_over_path(path)
	var err := ResourceSaver.save(profile, path)
	if err != OK:
		push_warning("tile_profile_editor: zapis %s nie powiódł się (%d)." % [path, err])


# --- inspektor ---

func _validate_property(p: Dictionary) -> void:
	match p.name:
		"miejsce":
			p.hint = PROPERTY_HINT_ENUM
			var items: PackedStringArray = []
			for i in _slots.size():
				var t: TileRef = _slots[i].holder.tile
				if tylko_puste and t != null and i != miejsce:
					continue
				items.append("%s:%d" % [_slot_label(i).replace(":", " ").replace(",", ";"), i])
			p.hint_string = ",".join(items)
		"zestaw":
			p.hint = PROPERTY_HINT_ENUM
			var items: PackedStringArray = []
			if profile:
				for i in profile.tilesets.size():
					items.append("%s:%d" % [String(profile.tilesets[i].id).replace(":", " ").replace(",", ";"), i])
			p.hint_string = ",".join(items)
		"zrodlo":
			p.hint = PROPERTY_HINT_ENUM
			var items: PackedStringArray = []
			for s in _sources:
				items.append("%s (%d):%d" % [s.name, s.id, s.id])
			p.hint_string = ",".join(items)
			p.usage = PROPERTY_USAGE_EDITOR
		"kafel", "alternatywa", "warstwa", "przesuniecie", "waga":
			p.usage = PROPERTY_USAGE_EDITOR


func _slot_label(i: int) -> String:
	var s: Dictionary = _slots[i]
	var g: Dictionary = _groups[s.group]
	var t: TileRef = s.holder.tile
	var ts := "pusta"
	if _erase(t):
		ts = "wymaż"
	elif t:
		ts = "%d %d;%d" % [t.source_id, t.atlas_coords.x, t.atlas_coords.y]
	var o := _offset(i)
	var layer := String((s.part as TileModulePart).layer) if s.part else "-"
	return "%s  (%d;%d) %s  [%s]" % [g.title, o.x, o.y, layer, ts]


# --- znaczniki ---

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
	if _slots.is_empty() or miejsce >= _slot_rects.size():
		return
	_place_marker("Wybor", _slot_rects[miejsce].get_center())
	var t := _cur_tile()
	if _valid(t):
		var src := _source(t.source_id)
		if not src.is_empty():
			_place_marker("Kafel", src.origin + (Vector2(t.atlas_coords) + Vector2(0.5, 0.5)) * _cell_px(src))


func _cell_px(src: Dictionary) -> Vector2:
	return Vector2((src.src as TileSetAtlasSource).texture_region_size) * AS


## Kratka atlasu pod punktem: [source_id, kratka] albo [].
func _atlas_at(pt: Vector2) -> Array:
	for s in _sources:
		var a := s.src as TileSetAtlasSource
		var cp := _cell_px(s)
		var r := Rect2(s.origin, Vector2(a.get_atlas_grid_size()) * cp)
		if r.has_point(pt):
			return [s.id, Vector2i((pt - s.origin) / cp)]
	return []


func _slot_at(pt: Vector2) -> int:
	for i in _slot_rects.size():
		if _slot_rects[i].has_point(pt):
			return i
	return -1


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var w := get_node_or_null("Wybor") as Node2D
	if w and _marker_last.has("Wybor") and w.position != _marker_last["Wybor"]:
		_marker_last["Wybor"] = w.position
		var i := _slot_at(w.position)
		if i >= 0 and i != miejsce:
			miejsce = i
	var k := get_node_or_null("Kafel") as Node2D
	if k and k.position != _marker_last.get("Kafel", k.position):
		_marker_last["Kafel"] = k.position
		var hit := _atlas_at(k.position)
		if not hit.is_empty():
			_set_tile(hit[0], hit[1], 0)
	elif k and not _marker_last.has("Kafel"):
		_marker_last["Kafel"] = k.position
	if _dirty >= 0.0:
		_dirty -= delta
		if _dirty < 0.0:
			_save()


# --- rysowanie ---

func _text(p: Vector2, s: String, size := 14, col := Color(0.85, 0.85, 0.85)) -> void:
	draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_ref(t: TileRef, r: Rect2) -> void:
	if t == null:
		draw_rect(r.grow(-2), COL_EMPTY, false, 2.0)
		return
	if _erase(t):
		draw_rect(r, Color(0.3, 0.3, 0.3))
		draw_line(r.position, r.end, Color(0.6, 0.6, 0.6), 2.0)
		return
	var src := _source(t.source_id)
	var a: TileSetAtlasSource = src.get("src")
	if a == null or not a.has_tile(t.atlas_coords):
		draw_rect(r, Color(COL_EMPTY, 0.5))
		draw_line(r.position, r.end, COL_EMPTY, 2.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), COL_EMPTY, 2.0)
		return
	draw_texture_rect_region(a.texture, r, a.get_tile_texture_region(t.atlas_coords))


func _draw() -> void:
	if profile == null:
		_text(Vector2(0, 0), "Przeciągnij profil .tres do „profile” albo utwórz nowy (grupa „Nowy profil”).", 22)
		return
	var d := _def()
	if d == null:
		_text(Vector2(0, 0), "Profil bez zestawów — utwórz nowy profil albo dodaj NamedTileSetDefinition.", 22)
		return
	var empty := 0
	for s in _slots:
		if s.holder.tile == null:
			empty += 1
	_text(Vector2(0, -10), "%s — zestaw %s, TileSet %s   |   części: %d, puste: %d" % [profile.resource_path.get_file(), d.id,
		d.tile_set.resource_path.get_file() if d.tile_set else "BRAK", _slots.size(), empty], 18)
	# podgląd zaznaczonej roli / wariantu (duży)
	draw_rect(Rect2(-10, 5, LIST_W + 10, LIST_Y - 20), Color(0.12, 0.12, 0.15))
	if not _slots.is_empty():
		var s := _cur()
		var g: Dictionary = _groups[s.group]
		_text(Vector2(0, 30), _slot_label(miejsce), 18, Color.WHITE)
		var b := _bounds(g.slots)
		var big := mini(96, int((LIST_Y - 70) / maxi(b.size.y, 1)))
		for si in g.slots:
			var o := _offset(si) - b.position
			var r := Rect2(Vector2(0, 45) + Vector2(o) * big, Vector2(big, big))
			draw_rect(r, Color(0.22, 0.22, 0.27))
			_draw_ref(_slots[si].holder.tile, r)
			if si == miejsce:
				draw_rect(r, COL_SEL, false, 3.0)
	# lista ról
	for g in _groups:
		var r: Rect2 = g.rect
		var sel: bool = not _slots.is_empty() and _cur().group == _groups.find(g)
		draw_rect(r, Color(0.3, 0.36, 0.55) if sel else Color(0.16, 0.16, 0.2))
		_text(r.position + Vector2(6, 15), g.title, 13)
		for si in g.slots:
			draw_rect(_slot_rects[si], Color(0.22, 0.22, 0.27))
			_draw_ref(_slots[si].holder.tile, _slot_rects[si])
	if miejsce < _slot_rects.size():
		draw_rect(_slot_rects[miejsce].grow(2), COL_SEL, false, 3.0)
	# atlasy
	var used := {}
	for s in _slots:
		var t: TileRef = s.holder.tile
		if _valid(t):
			used[Vector3i(t.source_id, t.atlas_coords.x, t.atlas_coords.y)] = true
	var cur := _cur_tile()
	for s in _sources:
		var a: TileSetAtlasSource = s.src
		var o: Vector2 = s.origin
		var cp := _cell_px(s)
		var grid := a.get_atlas_grid_size()
		var sz := Vector2(grid) * cp
		_text(o + Vector2(0, -10), "%s (źródło %d) — przeciągnij znacznik „Kafel” na kratkę" % [s.name, s.id], 20, Color.WHITE)
		draw_rect(Rect2(o, sz), Color(0.18, 0.18, 0.22))
		draw_texture_rect(a.texture, Rect2(o, a.texture.get_size() * AS), false)
		for cx in range(grid.x + 1):
			draw_line(o + Vector2(cx * cp.x, 0), o + Vector2(cx * cp.x, sz.y), Color(1, 0, 1, 0.25))
		for cy in range(grid.y + 1):
			draw_line(o + Vector2(0, cy * cp.y), o + Vector2(sz.x, cy * cp.y), Color(1, 0, 1, 0.25))
		for cx in grid.x:
			_text(o + Vector2(cx * cp.x + 2, sz.y + 14), str(cx), 12, Color(0.6, 0.6, 0.6))
		for cy in grid.y:
			_text(o + Vector2(-24, cy * cp.y + 16), str(cy), 12, Color(0.6, 0.6, 0.6))
		for key in used:
			if key.x == s.id:
				draw_rect(Rect2(o + Vector2(key.y, key.z) * cp, cp), Color(COL_USED, 0.22))
		if _valid(cur) and cur.source_id == s.id:
			draw_rect(Rect2(o + Vector2(cur.atlas_coords) * cp, cp), COL_SEL, false, 4.0)
