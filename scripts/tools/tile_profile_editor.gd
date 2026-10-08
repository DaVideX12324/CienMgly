@tool
extends Node2D

## Edytor profilu kafli (MapTileProfile .tres) od strony atlasu — w edytorze, jak podgląd układu walki:
## otwórz scenes/tools/tile_profile_editor.tscn, zaznacz korzeń sceny.
## 1. Profil: przeciągnij plik profilu do „profile” albo utwórz nowy (grupa „Nowy profil”: TileSet + ścieżka
##    pliku -> „Utwórz profil”). Profil z kilkoma zestawami — „zestaw”.
## 2. Kafel: przeciągnij znacznik „Kafel” na kratkę atlasu (po prawej) albo ustaw „zrodlo” / „kafel”.
##    „przypisania” pokazuje, czym ten kafel już jest (rola / wariant / przesunięcie / warstwa).
## 3. Przypisanie (grupa „Przypisanie”): rola, wariant, przesunięcie części w module, warstwa, alternatywa ->
##    „Przypisz”. Wybór istniejącego przypisania z listy „przypisanie” wypełnia pola; „Przypisz” wtedy je
##    zmienia, „Usuń przypisanie” usuwa. Pola zostają po zmianie kafla — kolejne kafle tej samej roli to
##    tylko przesunięcie znacznika i „Przypisz”.
## 4. Moduł z kilku kratek: zaznacz „modul” i przeciągnij znacznik „Koniec” na przeciwny róg prostokąta —
##    „Przypisz” nada każdej kratce przesunięcie = „przesuniecie” + (kratka − „kafel”).
## Po lewej podgląd wszystkich ról złożonych z obecnych kafli (z „wzor” — obok wygląd we wzorze); znacznik
## „Wybor” na części — skok do jej kafla. Atlasy = TileSet zestawu („tileset”).
## Przeniesienie profilu na nową paczkę: „profile” = stary, „nowy_tileset” = nowy TileSet, „nowy_plik” = ścieżka
## -> „Kopiuj obecny profil”; potem „wzor” = stary profil i przypisywanie kafli nowego atlasu.
## Na atlasie: kratki z przypisaniem podświetlone (z nazwą pierwszej roli), biała ramka — wybrany kafel,
## pomarańczowe — reszta modułu wybranego przypisania. Zmiany zapisują się same do pliku profilu.
## Bez cofania (Ctrl+Z) — w razie czego git.

const SAVE_DELAY := 0.6
const AS := 4                       # skala atlasów
const LIST_W := 1000.0              # szerokość kolumny ról
const PS := 32                      # bok kratki części na liście
const ATLAS_X := LIST_W + 140.0
const COL_EMPTY := Color(0.9, 0.3, 0.3)
const COL_SEL := Color(1, 1, 1)
const COL_USED := Color(0.35, 0.7, 1.0)
const COL_MODULE := Color(1.0, 0.6, 0.2)
const COL_RECT := Color(1.0, 0.9, 0.3)

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
## TileSet zestawu — z niego są atlasy po prawej (zmiana zapisuje się w profilu).
@export var tileset: TileSet:
	get:
		var d := _def()
		return d.tile_set if d else null
	set(v):
		var d := _def()
		if d and d.tile_set != v:
			d.tile_set = v
			_touch()
## Profil wzorcowy (opcjonalnie, np. sewer_map_tiles.tres przy przenoszeniu na nową paczkę): obok każdej roli
## jej wygląd we wzorze (ta sama rola / wariant / przesunięcie / warstwa). Tylko podgląd — nie jest zmieniany.
@export var wzor: MapTileProfile:
	set(v):
		wzor = v
		_rebuild()

@export_group("Nowy profil")
## TileSet nowego profilu (źródła atlasów).
@export var nowy_tileset: TileSet
## Ścieżka nowego pliku profilu, np. res://modules/quiz_rpg/resources/maps/profile/nowy_map_tiles.tres.
@export_file("*.tres") var nowy_plik := ""
@export_tool_button("Utwórz profil") var _b_create := _create_profile
## Kopia edytowanego profilu do „nowy_plik” (z TileSetem „nowy_tileset”, jeśli ustawiony) — i dalej edycja kopii.
@export_tool_button("Kopiuj obecny profil") var _b_copy := _copy_profile

@export_group("Kafel atlasu")
## Źródło atlasu (source_id) wybranego kafla.
@export var zrodlo := 0:
	set(v):
		zrodlo = v
		_on_cell_changed()
## Wybrany kafel atlasu (kolumna, wiersz).
@export var kafel := Vector2i.ZERO:
	set(v):
		kafel = v
		_on_cell_changed()
## Przypisanie prostokąta kratek jako modułu (od „kafel” do „koniec”).
@export var modul := false:
	set(v):
		modul = v
		_sync_markers()
		queue_redraw()
## Przeciwny róg prostokąta modułu.
@export var koniec := Vector2i.ZERO:
	set(v):
		koniec = v
		_sync_markers()
		queue_redraw()
## Czym wybrany kafel już jest (tylko do odczytu).
@export_multiline var przypisania := "":
	get:
		var lines: PackedStringArray = []
		for si in _cell_slots:
			lines.append(_slot_label(si))
		return "\n".join(lines) if not lines.is_empty() else "(nic)"
	set(v):
		pass

@export_group("Przypisanie")
## Istniejące przypisanie wybranego kafla do zmiany / usunięcia albo „nowe”.
@export var przypisanie := 0:
	set(v):
		przypisanie = clampi(v, 0, _cell_slots.size())
		if przypisanie > 0:
			_fill_form(_cell_slots[przypisanie - 1])
		_sync_markers()
		notify_property_list_changed()
		queue_redraw()
## Rola kafla.
@export var rola: TileRole.Id = TileRole.Id.NONE
## Wariant roli (A, B, …) — moduły jednej roli w kilku wersjach.
@export var wariant := &"A"
## Położenie kafla w module względem kotwicy (np. lico 3H: (0,-2), (0,-1), (0,0)).
@export var przesuniecie := Vector2i.ZERO
## Warstwa docelowa (Walls, Floor, FloorDecor, Props…).
@export var warstwa := &"Walls"
## Alternatywa kafla (np. wersja bez kolizji).
@export var alternatywa := 0
## Waga losowania wariantu.
@export var waga := 1.0
@export_tool_button("Przypisz") var _b_assign := _assign
@export_tool_button("Usuń przypisanie") var _b_remove := _remove_selected
@export_tool_button("Usuń cały wariant") var _b_del_var := _del_variant
@export_tool_button("Usuń całą rolę") var _b_del_role := _del_role

var _slots: Array = []              # {entry, variant, part, holder, group}
var _groups: Array = []             # {entry, variant, title, slots: [indeksy], rect}
var _slot_rects: Array[Rect2] = []
var _sources: Array = []            # {id, src: TileSetAtlasSource, name, origin}
var _by_cell := {}                  # Vector3i(źródło, x, y) -> [indeksy części]
var _cell_slots: Array = []         # części z kaflem wybranej kratki
var _dirty := -1.0
var _marker_last := {}
var _wzor_tiles := {}               # [rola, wariant, przesunięcie, warstwa] -> TileRef we wzorze
var _wzor_src := {}                 # source_id -> TileSetAtlasSource wzoru


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
	_by_cell.clear()
	var d := _def()
	if d:
		for e: TileRoleEntry in d.tile_entries:
			if e == null:
				continue
			var rname := _role_name(e.role)
			if e.variants.is_empty():
				if _valid(e.tile):
					_add_group(e, null, "%s (kafel)" % rname, [null])
				continue
			for v: TileVariant in e.variants:
				if not v.parts.is_empty():
					_add_group(e, v, "%s / %s" % [rname, v.variant_id], v.parts)
		if d.tile_set:
			var y := 40.0
			for i in d.tile_set.get_source_count():
				var sid := d.tile_set.get_source_id(i)
				var src := d.tile_set.get_source(sid) as TileSetAtlasSource
				if src == null or src.texture == null:
					continue
				var nm := src.texture.resource_path.get_file().get_basename()
				_sources.append({"id": sid, "src": src, "name": nm, "origin": Vector2(ATLAS_X, y)})
				y += src.texture.get_size().y * AS + 90
	_wzor_tiles.clear()
	_wzor_src.clear()
	var wd: NamedTileSetDefinition = wzor.tilesets[0] if wzor and not wzor.tilesets.is_empty() else null
	if wd and wd.tile_set:
		for i in wd.tile_set.get_source_count():
			var sid := wd.tile_set.get_source_id(i)
			if wd.tile_set.get_source(sid) is TileSetAtlasSource:
				_wzor_src[sid] = wd.tile_set.get_source(sid)
		for e: TileRoleEntry in wd.tile_entries:
			if e == null:
				continue
			if e.variants.is_empty():
				_wzor_tiles[[e.role, &"", Vector2i.ZERO, &""]] = e.tile
			for v: TileVariant in e.variants:
				for p: TileModulePart in v.parts:
					if p:
						_wzor_tiles[[e.role, v.variant_id, p.offset, p.layer]] = p.tile
	for i in _slots.size():
		var t: TileRef = _slots[i].holder.tile
		if _valid(t):
			var k := Vector3i(t.source_id, t.atlas_coords.x, t.atlas_coords.y)
			if not _by_cell.has(k):
				_by_cell[k] = []
			(_by_cell[k] as Array).append(i)
	_layout()
	_on_cell_changed()


func _add_group(e: TileRoleEntry, v: TileVariant, title: String, parts: Array) -> void:
	var g := {"entry": e, "variant": v, "title": title, "slots": []}
	for p in parts:
		if p == null and v != null:
			continue
		(g.slots as Array).append(_slots.size())
		_slots.append({"entry": e, "variant": v, "part": p, "holder": p if p else e, "group": _groups.size()})
	_groups.append(g)


## Lista ról (przepływ wierszami pod nagłówkiem) -> prostokąty części.
func _layout() -> void:
	_slot_rects.resize(_slots.size())
	var font := ThemeDB.fallback_font
	var x := 0.0
	var y := 40.0
	var row_h := 0.0
	for g in _groups:
		var b := _bounds(g.slots)
		var mw: float = b.size.x * PS * (2 if not _wzor_tiles.is_empty() else 1) + (8 if not _wzor_tiles.is_empty() else 0)
		var w: float = maxf(mw, font.get_string_size(g.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 16
		var h: float = 22 + b.size.y * PS + 10
		if x > 0 and x + w > LIST_W:
			x = 0
			y += row_h + 8
			row_h = 0
		g.rect = Rect2(x, y, w, h)
		g.wzor_dx = b.size.x * PS + 8
		for si in g.slots:
			var o := _offset(si) - b.position
			_slot_rects[si] = Rect2(x + 8 + o.x * PS, y + 22 + o.y * PS, PS, PS)
		x += w + 8
		row_h = maxf(row_h, h)


func _offset(si: int) -> Vector2i:
	var p = _slots[si].part
	return (p as TileModulePart).offset if p else Vector2i.ZERO


func _bounds(slot_ids: Array) -> Rect2i:
	if slot_ids.is_empty():
		return Rect2i(0, 0, 1, 1)
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := -mn
	for si in slot_ids:
		var o := _offset(si)
		mn = Vector2i(mini(mn.x, o.x), mini(mn.y, o.y))
		mx = Vector2i(maxi(mx.x, o.x), maxi(mx.y, o.y))
	return Rect2i(mn, mx - mn + Vector2i.ONE)


func _wzor_tile(si: int) -> TileRef:
	var s: Dictionary = _slots[si]
	var e: TileRoleEntry = s.entry
	if s.variant == null:
		return _wzor_tiles.get([e.role, &"", Vector2i.ZERO, &""])
	return _wzor_tiles.get([e.role, (s.variant as TileVariant).variant_id, _offset(si), (s.part as TileModulePart).layer])


func _source(sid: int) -> Dictionary:
	for s in _sources:
		if s.id == sid:
			return s
	return {}


func _on_cell_changed() -> void:
	_cell_slots = _by_cell.get(Vector3i(zrodlo, kafel.x, kafel.y), []).duplicate()
	przypisanie = 1 if not _cell_slots.is_empty() else 0


func _fill_form(si: int) -> void:
	var s: Dictionary = _slots[si]
	rola = (s.entry as TileRoleEntry).role
	wariant = (s.variant as TileVariant).variant_id if s.variant else &"A"
	przesuniecie = _offset(si)
	warstwa = (s.part as TileModulePart).layer if s.part else &"Walls"
	alternatywa = (s.holder.tile as TileRef).alternative_tile if s.holder.tile else 0
	waga = (s.variant as TileVariant).weight if s.variant else 1.0


func _touch() -> void:
	_dirty = SAVE_DELAY
	_rebuild()


# --- zmiany profilu ---

## Część roli / wariantu o danym przesunięciu i warstwie: istniejąca dostaje kafel, inaczej nowa.
func _put(role: int, vid: StringName, off: Vector2i, layer: StringName, t: TileRef) -> void:
	var d := _def()
	var e := _entry(d, role)
	if e == null:
		e = TileRoleEntry.new()
		e.role = role
		d.tile_entries.append(e)
	var v: TileVariant = null
	for vv: TileVariant in e.variants:
		if vv.variant_id == vid:
			v = vv
	if v == null:
		v = TileVariant.new()
		v.variant_id = vid
		e.variants.append(v)
	v.weight = waga
	for p: TileModulePart in v.parts:
		if p.offset == off and p.layer == layer:
			p.tile = t
			return
	var np := TileModulePart.new()
	np.offset = off
	np.layer = layer
	np.tile = t
	v.parts.append(np)


func _remove_slot(si: int) -> void:
	var s: Dictionary = _slots[si]
	var e: TileRoleEntry = s.entry
	if s.part == null:
		e.tile = null
	else:
		var v: TileVariant = s.variant
		v.parts.erase(s.part)
		if v.parts.is_empty():
			e.variants.erase(v)
	if e.variants.is_empty() and not _valid(e.tile):
		_def().tile_entries.erase(e)


func _assign() -> void:
	if _def() == null or rola == TileRole.Id.NONE:
		push_warning("tile_profile_editor: wybierz rolę.")
		return
	if przypisanie > 0:
		_remove_slot(_cell_slots[przypisanie - 1])
	var cells: Array[Vector2i] = [kafel]
	if modul:
		cells.clear()
		var a := Vector2i(mini(kafel.x, koniec.x), mini(kafel.y, koniec.y))
		var b := Vector2i(maxi(kafel.x, koniec.x), maxi(kafel.y, koniec.y))
		for y in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				cells.append(Vector2i(x, y))
	var src := _source(zrodlo)
	for c in cells:
		if not src.is_empty() and not (src.src as TileSetAtlasSource).has_tile(c):
			continue
		_put(rola, wariant, przesuniecie + (c - kafel), warstwa, _ref(c, zrodlo, alternatywa))
	# przebudowa listy wypełnia formularz pierwszym przypisaniem kratki — zapamiętaj nowe i wskaż je potem
	var want := [rola, wariant, przesuniecie, warstwa]
	_touch()
	for i in _cell_slots.size():
		var s: Dictionary = _slots[_cell_slots[i]]
		if s.variant and [(s.entry as TileRoleEntry).role, (s.variant as TileVariant).variant_id, _offset(_cell_slots[i]),
				(s.part as TileModulePart).layer] == want:
			przypisanie = i + 1


func _remove_selected() -> void:
	if przypisanie > 0:
		_remove_slot(_cell_slots[przypisanie - 1])
		_touch()


func _del_variant() -> void:
	if przypisanie <= 0:
		return
	var s: Dictionary = _slots[_cell_slots[przypisanie - 1]]
	var e: TileRoleEntry = s.entry
	if s.variant:
		e.variants.erase(s.variant)
	else:
		e.tile = null
	if e.variants.is_empty() and not _valid(e.tile):
		_def().tile_entries.erase(e)
	_touch()


func _del_role() -> void:
	if przypisanie <= 0:
		return
	_def().tile_entries.erase(_slots[_cell_slots[przypisanie - 1]].entry)
	_touch()


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


func _copy_profile() -> void:
	if profile == null or nowy_plik == "":
		push_warning("tile_profile_editor: ustaw „profile” i „nowy_plik” (ścieżka kopii).")
		return
	var p: MapTileProfile = profile.duplicate(true)
	if nowy_tileset:
		for d: NamedTileSetDefinition in p.tilesets:
			d.tile_set = nowy_tileset
	var err := ResourceSaver.save(p, nowy_plik)
	if err != OK:
		push_warning("tile_profile_editor: zapis %s nie powiódł się (%d)." % [nowy_plik, err])
		return
	p.take_over_path(nowy_plik)
	profile = p
	print("tile_profile_editor: kopia profilu w %s" % nowy_plik)


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
		"przypisanie":
			p.hint = PROPERTY_HINT_ENUM
			var items: PackedStringArray = ["nowe:0"]
			for i in _cell_slots.size():
				items.append("%s:%d" % [_slot_label(_cell_slots[i]).replace(":", " ").replace(",", ";"), i + 1])
			p.hint_string = ",".join(items)
			p.usage = PROPERTY_USAGE_EDITOR
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
		"przypisania":
			p.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		"tileset":
			p.usage = PROPERTY_USAGE_EDITOR


func _slot_label(si: int) -> String:
	var s: Dictionary = _slots[si]
	var g: Dictionary = _groups[s.group]
	var t: TileRef = s.holder.tile
	var o := _offset(si)
	var layer := String((s.part as TileModulePart).layer) if s.part else "-"
	var alt := " alt %d" % t.alternative_tile if t and t.alternative_tile != 0 else ""
	return "%s  (%d, %d)  %s%s" % [g.title, o.x, o.y, layer, alt]


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


func _cell_px(src: Dictionary) -> Vector2:
	return Vector2((src.src as TileSetAtlasSource).texture_region_size) * AS


func _cell_center(sid: int, c: Vector2i) -> Vector2:
	var src := _source(sid)
	if src.is_empty():
		return Vector2.ZERO
	return src.origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell_px(src)


func _sync_markers() -> void:
	if _sources.is_empty():
		return
	_place_marker("Kafel", _cell_center(zrodlo, kafel))
	var src := _source(zrodlo)
	if not src.is_empty():
		var end := koniec if modul else kafel
		_place_marker("Koniec", _cell_center(zrodlo, end) + _cell_px(src) * 0.3)
	if przypisanie > 0 and przypisanie - 1 < _cell_slots.size():
		_place_marker("Wybor", _slot_rects[_cell_slots[przypisanie - 1]].get_center())


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


func _moved(n: String) -> Node2D:
	var m := get_node_or_null(n) as Node2D
	if m == null:
		return null
	if not _marker_last.has(n):
		_marker_last[n] = m.position
		return null
	if m.position == _marker_last[n]:
		return null
	_marker_last[n] = m.position
	return m


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var k := _moved("Kafel")
	if k:
		var hit := _atlas_at(k.position)
		if not hit.is_empty() and (hit[0] != zrodlo or hit[1] != kafel):
			zrodlo = hit[0]
			kafel = hit[1]
			notify_property_list_changed()
	var e := _moved("Koniec")
	if e:
		var hit := _atlas_at(e.position)
		if not hit.is_empty() and hit[0] == zrodlo and hit[1] != kafel:
			koniec = hit[1]
			modul = true
			notify_property_list_changed()
	var w := _moved("Wybor")
	if w:
		var si := _slot_at(w.position)
		if si >= 0:
			var t: TileRef = _slots[si].holder.tile
			zrodlo = t.source_id
			kafel = t.atlas_coords
			przypisanie = _cell_slots.find(si) + 1
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
		_text(Vector2(0, 0), "Profil bez zestawów — utwórz nowy profil.", 22)
		return
	var missing := 0
	for r in TileRole.Id.values():
		if r != TileRole.Id.NONE and _entry(d, r) == null:
			missing += 1
	_text(Vector2(0, 0), "%s — zestaw %s, TileSet %s   |   ról: %d, bez kafli: %d" % [profile.resource_path.get_file(), d.id,
		d.tile_set.resource_path.get_file() if d.tile_set else "BRAK", d.tile_entries.size(), missing], 18, Color.WHITE)
	var sel_slot: int = _cell_slots[przypisanie - 1] if przypisanie > 0 and przypisanie - 1 < _cell_slots.size() else -1
	var sel_group: int = _slots[sel_slot].group if sel_slot >= 0 else -1
	# lista ról (podgląd złożonych modułów)
	for gi in _groups.size():
		var g: Dictionary = _groups[gi]
		var r: Rect2 = g.rect
		draw_rect(r, Color(0.3, 0.36, 0.55) if gi == sel_group else Color(0.16, 0.16, 0.2))
		_text(r.position + Vector2(6, 15), g.title, 13)
		for si in g.slots:
			draw_rect(_slot_rects[si], Color(0.22, 0.22, 0.27))
			_draw_ref(_slots[si].holder.tile, _slot_rects[si])
			if not _wzor_tiles.is_empty():
				var wr := Rect2(_slot_rects[si].position + Vector2(g.wzor_dx, 0), _slot_rects[si].size)
				draw_rect(wr, Color(0.14, 0.14, 0.17))
				var wt := _wzor_tile(si)
				if _valid(wt) and _wzor_src.has(wt.source_id) and (_wzor_src[wt.source_id] as TileSetAtlasSource).has_tile(wt.atlas_coords):
					var ws: TileSetAtlasSource = _wzor_src[wt.source_id]
					draw_texture_rect_region(ws.texture, wr, ws.get_tile_texture_region(wt.atlas_coords), Color(1, 1, 1, 0.85))
	if sel_slot >= 0:
		draw_rect(_slot_rects[sel_slot].grow(2), COL_SEL, false, 3.0)
	var module_cells := {}
	if sel_group >= 0:
		for si in _groups[sel_group].slots:
			var t: TileRef = _slots[si].holder.tile
			if _valid(t):
				module_cells[Vector3i(t.source_id, t.atlas_coords.x, t.atlas_coords.y)] = true
	# atlasy
	for s in _sources:
		var a: TileSetAtlasSource = s.src
		var o: Vector2 = s.origin
		var cp := _cell_px(s)
		var grid := a.get_atlas_grid_size()
		var sz := Vector2(grid) * cp
		_text(o + Vector2(0, -12), "%s (źródło %d) — znacznik „Kafel” na kratkę; „Koniec” = prostokąt modułu" % [s.name, s.id], 20, Color.WHITE)
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
		for key in _by_cell:
			if key.x != s.id:
				continue
			var r := Rect2(o + Vector2(key.y, key.z) * cp, cp)
			draw_rect(r, Color(COL_USED, 0.25))
			var first: Dictionary = _slots[_by_cell[key][0]]
			var nm := _role_name((first.entry as TileRoleEntry).role)
			var more: int = _by_cell[key].size() - 1
			_text(r.position + Vector2(2, cp.y - 4), nm.substr(0, 9) + ("+%d" % more if more > 0 else ""), 9, Color(1, 1, 1, 0.9))
			if module_cells.has(key):
				draw_rect(r, COL_MODULE, false, 3.0)
		if s.id == zrodlo:
			if modul:
				var a0 := Vector2i(mini(kafel.x, koniec.x), mini(kafel.y, koniec.y))
				var a1 := Vector2i(maxi(kafel.x, koniec.x), maxi(kafel.y, koniec.y))
				draw_rect(Rect2(o + Vector2(a0) * cp, Vector2(a1 - a0 + Vector2i.ONE) * cp), COL_RECT, false, 3.0)
			draw_rect(Rect2(o + Vector2(kafel) * cp, cp), COL_SEL, false, 4.0)
