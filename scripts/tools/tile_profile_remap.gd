extends Control

## Przypisywanie kafli profilu ścieków do nowej paczki (uruchamiać scenę F6 z edytora).
## Lewo: kafle starego profilu (role / warianty) i obiektów — stary kafel, przypisany nowy, stan; nad grupą podgląd
## całego modułu (stary | nowy). Prawo: atlas nowej paczki (Tiles / Water / Props) — klik przypisuje kratkę
## zaznaczonemu kaflowi; kratki już użyte podświetlone. Zapis: sewer_v2_remap.json + nowy profil
## sewer_v2_map_tiles.tres (kopia starego z podmienionymi kaflami, TileSet sewer_v2.tres).
## Stany: auto (identyczny, wynik 0), ręcznie (przypisane tutaj), sugestia (najbliższy z tabeli — do zatwierdzenia).

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
const NEW_SOURCE := {"Tiles": 0, "Props": 1, "Water": 2}
const OLD_SOURCE_NAME := {0: "Tiles", 1: "Props"}
const STATUS_COLOR := {"auto": Color(0.45, 0.85, 0.5), "ręcznie": Color(0.4, 0.75, 1.0), "sugestia": Color(0.95, 0.8, 0.35), "brak": Color(0.95, 0.4, 0.4)}
const ZOOM := 3

var remap: Dictionary = {}          # "Tiles:x,y" -> {label, atlas, coords, status}
var groups: Array = []              # {title, parts: [{key, offset}]}
var old_tex := {}
var new_tex := {}
var selected := ""
var atlas_name := "Tiles"
var only_open := false

var list_box: VBoxContainer
var atlas_view: Control
var info: Label
var row_widgets := {}               # key -> {new_rect, status_label, panel}
var group_previews: Array = []      # Control podglądów modułów (odświeżane)


func _ready() -> void:
	for k in OLD_TEX:
		old_tex[k] = load(OLD_TEX[k])
	for k in NEW_TEX:
		new_tex[k] = load(NEW_TEX[k])
	_load_remap()
	_load_groups()
	_build_ui()
	_rebuild_list()


func _load_remap() -> void:
	var f := FileAccess.open(QuizRpgPaths.path(REMAP), FileAccess.READ)
	remap = JSON.parse_string(f.get_as_text()) if f else {}


func _key(src: int, c: Vector2i) -> String:
	return "%s:%d,%d" % [OLD_SOURCE_NAME.get(src, "Tiles"), c.x, c.y]


## Grupy z profilu (rola / wariant -> części) i z mapowania (obiekty — pojedyncze kafle).
func _load_groups() -> void:
	var prof: MapTileProfile = load(QuizRpgPaths.path(OLD_PROFILE))
	var covered := {}
	for ts_def in prof.tilesets:
		for e: TileRoleEntry in ts_def.tile_entries:
			var rname := TileRole.name_of(e.role)
			if e.tile != null and e.tile.is_valid():
				var k0 := _key(e.tile.source_id, e.tile.atlas_coords)
				covered[k0] = true
				if not remap.has(k0):
					remap[k0] = {"label": rname, "atlas": "", "coords": [0, 0], "status": "brak"}
				groups.append({"title": "%s (kafel)" % rname, "parts": [{"key": k0, "offset": Vector2i.ZERO}]})
			for v: TileVariant in e.variants:
				var parts: Array = []
				for p: TileModulePart in v.parts:
					if p == null or p.tile == null or not p.tile.is_valid():
						continue
					var k := _key(p.tile.source_id, p.tile.atlas_coords)
					parts.append({"key": k, "offset": p.offset})
					covered[k] = true
					if not remap.has(k):
						remap[k] = {"label": "%s/%s" % [rname, v.variant_id], "atlas": "", "coords": [0, 0], "status": "brak"}
				if not parts.is_empty():
					groups.append({"title": "%s / %s" % [rname, v.variant_id], "parts": parts})
	var objs := {}
	for k in remap:
		if covered.has(k):
			continue
		var lab: String = remap[k].get("label", k)
		if not objs.has(lab):
			objs[lab] = []
		(objs[lab] as Array).append({"key": k, "offset": Vector2i(objs[lab].size(), 0)})
	for lab in objs:
		groups.append({"title": lab, "parts": objs[lab]})


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.split_offset = 560
	add_child(split)
	var left := VBoxContainer.new()
	split.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	var cb := CheckBox.new()
	cb.text = "tylko niezatwierdzone"
	cb.toggled.connect(func(on: bool) -> void:
		only_open = on
		_rebuild_list())
	top.add_child(cb)
	for t in [["Zatwierdź sugestię", _accept], ["Następny niezatwierdzony", _next_open], ["Zapisz", _save]]:
		var b := Button.new()
		b.text = t[0]
		b.pressed.connect(t[1])
		top.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)

	var right := VBoxContainer.new()
	split.add_child(right)
	var tabs := HBoxContainer.new()
	right.add_child(tabs)
	for n in NEW_TEX:
		var b := Button.new()
		b.text = n
		b.toggle_mode = true
		b.button_pressed = n == atlas_name
		b.pressed.connect(func() -> void:
			atlas_name = n
			for c in tabs.get_children():
				(c as Button).button_pressed = (c as Button).text == n
			_refresh_atlas())
		tabs.add_child(b)
	info = Label.new()
	info.text = "Zaznacz kafel po lewej, potem kliknij kratkę atlasu."
	right.add_child(info)
	var asc := ScrollContainer.new()
	asc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(asc)
	atlas_view = Control.new()
	atlas_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atlas_view.draw.connect(_draw_atlas)
	atlas_view.gui_input.connect(_atlas_input)
	asc.add_child(atlas_view)
	_refresh_atlas()


func _tile_tex(tex: Texture2D, c: Vector2i) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(c.x * 16, c.y * 16, 16, 16)
	return a


func _old_tile(key: String) -> AtlasTexture:
	var p := key.split(":")
	var xy := p[1].split(",")
	return _tile_tex(old_tex[p[0]], Vector2i(int(xy[0]), int(xy[1])))


func _new_tile(key: String) -> AtlasTexture:
	var m: Dictionary = remap.get(key, {})
	if String(m.get("atlas", "")) == "":
		return null
	return _tile_tex(new_tex[m.atlas], Vector2i(int(m.coords[0]), int(m.coords[1])))


func _rect(tex: Texture2D, size: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


func _rebuild_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	row_widgets.clear()
	group_previews.clear()
	for g in groups:
		var open := false
		for p in g.parts:
			if remap[p.key].status in ["sugestia", "brak"]:
				open = true
		if only_open and not open:
			continue
		var head := HBoxContainer.new()
		list_box.add_child(head)
		var t := Label.new()
		t.text = g.title
		t.custom_minimum_size.x = 220
		head.add_child(t)
		var prev := Control.new()
		prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prev.set_meta("parts", g.parts)
		prev.draw.connect(_draw_module.bind(prev))
		head.add_child(prev)
		group_previews.append(prev)
		_size_module(prev)
		for p in g.parts:
			_add_row(p.key)
		list_box.add_child(HSeparator.new())


func _add_row(key: String) -> void:
	var row := HBoxContainer.new()
	var panel := PanelContainer.new()
	panel.add_child(row)
	list_box.add_child(panel)
	var b := Button.new()
	b.text = "›"
	b.pressed.connect(_select.bind(key))
	row.add_child(b)
	row.add_child(_rect(_old_tile(key), 48))
	var arrow := Label.new()
	arrow.text = " → "
	row.add_child(arrow)
	var nr := _rect(_new_tile(key), 48)
	row.add_child(nr)
	var st := Label.new()
	row.add_child(st)
	row_widgets[key] = {"new": nr, "status": st, "panel": panel}
	_refresh_row(key)


func _refresh_row(key: String) -> void:
	if not row_widgets.has(key):
		return
	var w: Dictionary = row_widgets[key]
	var m: Dictionary = remap[key]
	(w.new as TextureRect).texture = _new_tile(key)
	var s: String = m.status
	(w.status as Label).text = "  %s  →  %s  [%s]" % [key, ("%s (%d,%d)" % [m.atlas, m.coords[0], m.coords[1]]) if m.atlas != "" else "—", s]
	(w.status as Label).add_theme_color_override("font_color", STATUS_COLOR.get(s, Color.WHITE))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.3, 0.45) if key == selected else Color(0, 0, 0, 0)
	(w.panel as PanelContainer).add_theme_stylebox_override("panel", sb)


func _select(key: String) -> void:
	var prev := selected
	selected = key
	_refresh_row(prev)
	_refresh_row(key)
	var m: Dictionary = remap[key]
	if m.atlas != "" and m.atlas != atlas_name:
		atlas_name = m.atlas
	info.text = "Zaznaczony: %s (%s) — kliknij kratkę atlasu %s." % [m.get("label", key), key, atlas_name]
	_refresh_atlas()


func _accept() -> void:
	if selected != "" and remap[selected].status == "sugestia":
		remap[selected].status = "ręcznie"
		_refresh_row(selected)
		_refresh_previews()


func _next_open() -> void:
	for g in groups:
		for p in g.parts:
			if remap[p.key].status in ["sugestia", "brak"] and p.key != selected:
				_select(p.key)
				return


func _refresh_atlas() -> void:
	var tex: Texture2D = new_tex[atlas_name]
	atlas_view.custom_minimum_size = tex.get_size() * ZOOM
	atlas_view.queue_redraw()


func _draw_atlas() -> void:
	var tex: Texture2D = new_tex[atlas_name]
	atlas_view.draw_rect(Rect2(Vector2.ZERO, tex.get_size() * ZOOM), Color(0.18, 0.18, 0.22))
	atlas_view.draw_texture_rect(tex, Rect2(Vector2.ZERO, tex.get_size() * ZOOM), false)
	var cells := Vector2i(tex.get_size()) / 16
	for x in range(cells.x + 1):
		atlas_view.draw_line(Vector2(x * 16 * ZOOM, 0), Vector2(x * 16 * ZOOM, cells.y * 16 * ZOOM), Color(1, 0, 1, 0.35))
	for y in range(cells.y + 1):
		atlas_view.draw_line(Vector2(0, y * 16 * ZOOM), Vector2(cells.x * 16 * ZOOM, y * 16 * ZOOM), Color(1, 0, 1, 0.35))
	for k in remap:
		var m: Dictionary = remap[k]
		if m.atlas != atlas_name:
			continue
		var r := Rect2(Vector2(m.coords[0], m.coords[1]) * 16 * ZOOM, Vector2.ONE * 16 * ZOOM)
		var col: Color = STATUS_COLOR.get(m.status, Color.WHITE)
		atlas_view.draw_rect(r, Color(col, 0.18))
		if k == selected:
			atlas_view.draw_rect(r, Color.WHITE, false, 3.0)


func _atlas_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or selected == "":
		return
	var c := Vector2i((ev as InputEventMouseButton).position / (16 * ZOOM))
	remap[selected].atlas = atlas_name
	remap[selected].coords = [c.x, c.y]
	remap[selected].status = "ręcznie"
	_refresh_row(selected)
	_refresh_previews()
	atlas_view.queue_redraw()
	info.text = "%s -> %s (%d,%d)" % [selected, atlas_name, c.x, c.y]


## Podgląd modułu: stary | nowy, części ułożone wg offsetów.
func _size_module(c: Control) -> void:
	var r := _module_bounds(c.get_meta("parts"))
	c.custom_minimum_size = Vector2((r.size.x * 2 + 1) * 16 * 2 + 8, r.size.y * 16 * 2)


func _module_bounds(parts: Array) -> Rect2i:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := -mn
	for p in parts:
		var o: Vector2i = p.offset
		mn = Vector2i(mini(mn.x, o.x), mini(mn.y, o.y))
		mx = Vector2i(maxi(mx.x, o.x), maxi(mx.y, o.y))
	return Rect2i(mn, mx - mn + Vector2i.ONE)


func _draw_module(c: Control) -> void:
	var parts: Array = c.get_meta("parts")
	var r := _module_bounds(parts)
	var s := 32
	for side: int in 2:
		var x0: int = side * ((r.size.x + 1) * s + 8)
		c.draw_rect(Rect2(x0, 0, r.size.x * s, r.size.y * s), Color(0.2, 0.2, 0.25))
		for p in parts:
			var o: Vector2i = p.offset - r.position
			var t: Texture2D = _old_tile(p.key) if side == 0 else _new_tile(p.key)
			if t != null:
				c.draw_texture_rect(t, Rect2(x0 + o.x * s, o.y * s, s, s), false)


func _refresh_previews() -> void:
	for p in group_previews:
		if is_instance_valid(p):
			p.queue_redraw()


func _save() -> void:
	var f := FileAccess.open(QuizRpgPaths.path(REMAP), FileAccess.WRITE)
	f.store_string(JSON.stringify(remap, " "))
	f.close()
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
				var m: Dictionary = remap.get(_key(t.source_id, t.atlas_coords), {})
				if String(m.get("atlas", "")) == "":
					missing += 1
					continue
				# alternatywy (np. brzegi bez kolizji pod kładką) dojdą razem z kolizjami w sewer_v2.tres
				holder.tile = TileRef.make(Vector2i(int(m.coords[0]), int(m.coords[1])), NEW_SOURCE[m.atlas], 0)
	var err := ResourceSaver.save(prof, QuizRpgPaths.path(NEW_PROFILE))
	var open := 0
	for k in remap:
		if remap[k].status in ["sugestia", "brak"]:
			open += 1
	info.text = "Zapisano %s i profil %s (błąd %d). Niezatwierdzone: %d, bez przypisania: %d." % [REMAP, NEW_PROFILE, err, open, missing]
