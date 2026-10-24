extends AudioStreamPlayer2D

## Dźwięki kroków gracza (wzór: Amon-Ra, player.gd play_footstep_sfx). Krok na klatkach animacji chodu
## (walk / walk_<kierunek>) z wykrokiem: ¼ i ¾ pętli (8 klatek: 2 i 6 jak w Amon-Ra, 4 klatki: 1 i 3) — dwa kroki
## na cykl, przy biegu szybciej razem z animacją; chód z bezruchu zaczyna się od klatki 1 (player.gd), więc
## pierwszy krok słychać od razu.
## Zapas jak w Amon-Ra: gdy postać idzie, a animacja chodu nie gra (np. trafienie), krok co pół pętli z licznika.
## Typ podłoża: najwyższa widoczna warstwa kafli pod stopami z rozpoznanym podłożem — dana kafla „ground_type”
## (jeśli TileSet ma taką warstwę danych), inaczej nazwa terenu kafla dopasowana do sets[].terrain_keywords
## (pierwszy pasujący zestaw); nic nie pasuje -> podłoże tilesetu z tileset_defaults (kafle bez terenów, np. podłoga
## ścieków), a bez niego default_ground. Tylko lider drużyny (towarzysze idą cicho).
## Zestawy i głośność w scenie scenes/player/footsteps.tscn.

@export var sets: Array[QuizRpgFootstepSet] = []
@export var default_ground := "ground"
## Podłoże dla kafli bez rozpoznanego terenu: fragment nazwy pliku TileSetu -> ground_type (np. "sewer" -> "stone").
@export var tileset_defaults: Dictionary = {}
@export var pitch_range := Vector2(0.9, 1.1)
## Punkt stóp względem gracza (kafel pod nim decyduje o podłożu).
@export var foot_offset := Vector2(0, 6)

var _sprite: AnimatedSprite2D
var _fallback_left := 0.0
var _layers: Array[TileMapLayer] = []
var _base_volume_db := 0.0


func _ready() -> void:
	_base_volume_db = volume_db
	bus = &"SFX_Env"
	_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite:
		_sprite.frame_changed.connect(_on_frame_changed)


func _physics_process(delta: float) -> void:
	var walker := get_parent()
	if _sprite == null or walker.get("_is_moving") != true or _is_walk_anim():
		_fallback_left = 0.0
		return
	_fallback_left -= delta
	if _fallback_left <= 0.0:
		_fallback_left = _half_loop_seconds()
		play_step()


func _is_walk_anim() -> bool:
	return String(_sprite.animation).begins_with("walk")


func _on_frame_changed() -> void:
	if not _is_walk_anim():
		return
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if n >= 2 and (_sprite.frame == int(n * 0.25) or _sprite.frame == int(n * 0.75)):
		play_step()


## Pół pętli chodu w sekundach (zapasowy licznik); bez animacji chodu — 0,3 s.
func _half_loop_seconds() -> float:
	var frames := _sprite.sprite_frames
	for anim: StringName in [&"walk_down", &"walk"]:
		if frames.has_animation(anim) and frames.get_animation_speed(anim) > 0.0:
			return frames.get_frame_count(anim) / frames.get_animation_speed(anim) / 2.0 / maxf(_sprite.speed_scale, 0.1)
	return 0.3


func play_step() -> void:
	if get_parent().get("is_party_follower") == true:
		return
	var chosen := find_set(ground_type_at((get_parent() as Node2D).global_position + foot_offset))
	var sound := chosen.random_sound() if chosen else null
	if sound == null:
		return
	stream = sound
	volume_db = _base_volume_db + chosen.volume_offset_db
	pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	play()


func find_set(ground_type: String) -> QuizRpgFootstepSet:
	var fallback: QuizRpgFootstepSet = null
	for s in sets:
		if s.ground_type == ground_type:
			return s
		if s.ground_type == default_ground:
			fallback = s
	return fallback


## Typ podłoża w punkcie (świat): warstwy od wierzchu (z_index, potem kolejność rysowania), pierwsza z rozpoznanym kaflem.
func ground_type_at(point: Vector2) -> String:
	var tileset_ground := ""
	for layer in _sorted_layers():
		if not layer.is_visible_in_tree():
			continue
		var data := layer.get_cell_tile_data(layer.local_to_map(layer.to_local(point)))
		if data == null:
			continue
		var found := _ground_of(layer.tile_set, data)
		if found != "":
			return found
		if tileset_ground == "":
			tileset_ground = _tileset_default(layer.tile_set)
	return tileset_ground if tileset_ground != "" else default_ground


func _tileset_default(ts: TileSet) -> String:
	var file := ts.resource_path.get_file() if ts else ""
	for key: String in tileset_defaults:
		if file.contains(key):
			return str(tileset_defaults[key])
	return ""


func _ground_of(ts: TileSet, data: TileData) -> String:
	if data.has_custom_data("ground_type"):
		var custom := str(data.get_custom_data("ground_type"))
		if custom != "":
			return custom
	if data.terrain_set < 0 or data.terrain < 0:
		return ""
	var terrain := ts.get_terrain_name(data.terrain_set, data.terrain).to_lower()
	for s in sets:
		for k in s.terrain_keywords:
			if terrain.contains(k):
				return s.ground_type
	return ""


## Warstwy kafli bieżącej mapy od wierzchu; lista odświeżana, gdy mapa się zmieni (stare warstwy zwolnione).
func _sorted_layers() -> Array[TileMapLayer]:
	var valid := not _layers.is_empty()
	for l in _layers:
		if not is_instance_valid(l) or not l.is_inside_tree():
			valid = false
			break
	if valid:
		return _layers
	_layers.clear()
	var order := {}
	for n in get_tree().root.find_children("*", "TileMapLayer", true, false):
		if (n as TileMapLayer).get_canvas_layer_node() == null:  # bez kopii mapy w UI (minimapa)
			order[n] = order.size()
			_layers.append(n as TileMapLayer)
	# Od wierzchu: wyższy z_index, przy równym — później w drzewie (rysowane wyżej).
	_layers.sort_custom(func(a: TileMapLayer, b: TileMapLayer) -> bool:
		return a.z_index > b.z_index if a.z_index != b.z_index else order[a] > order[b])
	return _layers
