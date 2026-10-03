extends Node

## Globalny serwis audio -- muzyka, SFX (UI + spatial), busy AudioServer.
## Rejestrowany jako autoload w host project.godot pod nazwa "AudioService".
## Do uzycia w standalone: skopiuj ten plik do modulu i zarejestruj pod
## ta sama nazwa w standalone_project.godot.example (patrz docs/module_contract.md).
## Kod woluje bezposrednio AudioService.play_music(...) itd. -- to prawdziwy
## autoload, NIE przechodzi przez CoreManager.get_singleton() (ten jest
## czyszczony przy kazdym przelaczeniu modulu, audio ma byc trwale).
##
## Utwory muzyczne nie sa preloadowane na starcie -- mapa nazwa->sciezka
## jest wczytywana z JSON (MUSIC_TRACKS_JSON_PATH), a same pliki .ogg
## sa doladowywane leniwie (load()) przy pierwszym uzyciu i cache'owane.

const MUSIC_MIN_DB := -60.0
const SFX_MIN_DB := -60.0
const MASTER_MIN_DB := -60.0
const MUTE_DB := -80.0

const MUSIC_TRACKS_JSON_PATH := "res://_host/resources/audio/music_tracks.json"

signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)
signal master_volume_changed(volume: float)
signal music_changed(track_name: String)
signal mute_toggled(is_muted: bool)

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

var sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 16

var is_muted: bool = false:
	set(value):
		is_muted = value
		_apply_master_volume()
		mute_toggled.emit(is_muted)

var current_track: String = ""
var previous_track: String = ""

var music_volume: float = 0.8:
	set(value):
		music_volume = clamp(value, 0.0, 1.0)
		_apply_music_volume()
		music_volume_changed.emit(music_volume)

var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clamp(value, 0.0, 1.0)
		_apply_sfx_volume()
		sfx_volume_changed.emit(sfx_volume)

var master_volume: float = 1.0:
	set(value):
		master_volume = clamp(value, 0.0, 1.0)
		_apply_master_volume()
		master_volume_changed.emit(master_volume)

## Nazwa -> sciezka res:// (wczytane z JSON, bez zaladowanych zasobow)
var music_track_paths: Dictionary = {}
## Cache zaladowanych AudioStream, wypelniany leniwie
var _music_stream_cache: Dictionary = {}

const PREFERENCES_PATH := "user://preferences.dat"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_bus(BUS_MASTER)
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)

	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	music_player.name = "MusicPlayer"
	add_child(music_player)

	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = BUS_MUSIC
	ambience_player.name = "AmbiencePlayer"
	add_child(ambience_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.name = "SFXPlayer%d" % i
		add_child(player)
		sfx_pool.append(player)

	_load_music_tracks_manifest()
	load_audio_settings()
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_master_volume()


func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	return index


func _load_music_tracks_manifest() -> void:
	music_track_paths.clear()
	if not FileAccess.file_exists(MUSIC_TRACKS_JSON_PATH):
		push_warning("[AudioService] Brak manifestu: %s" % MUSIC_TRACKS_JSON_PATH)
		return
	var text := FileAccess.get_file_as_string(MUSIC_TRACKS_JSON_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[AudioService] Niepoprawny JSON w %s" % MUSIC_TRACKS_JSON_PATH)
		return
	var parsed_dict: Dictionary = parsed
	for key in parsed_dict.keys():
		var track_key: String = key
		var track_path: String = str(parsed_dict[key])
		music_track_paths[track_key] = track_path


func _get_music_stream(track_name: String) -> AudioStream:
	if _music_stream_cache.has(track_name):
		return _music_stream_cache[track_name]
	if not music_track_paths.has(track_name):
		return null
	var path: String = music_track_paths[track_name]
	if not ResourceLoader.exists(path):
		push_warning("[AudioService] Plik nie istnieje: %s (%s)" % [track_name, path])
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		ogg_stream.loop = true
		ogg_stream.loop_offset = 3.0
	_music_stream_cache[track_name] = stream
	return stream


const DEFAULT_SFX: Dictionary = {
	"click": "res://_host/assets/audio/sfx/RPG Sound Pack/interface/interface1.wav",
	"hover": "res://_host/assets/audio/sfx/RPG Sound Pack/interface/interface4.wav",
	"correct": "res://_host/assets/audio/sfx/RPG Sound Pack/inventory/coin.wav",
	"wrong": "res://_host/assets/audio/sfx/Helton Yan's Pixel Combat - Single Files/DSGNImpt_EXPLOSION-Forced Shutdown_HY_PC-001.wav",
	"attack": "res://_host/assets/audio/sfx/RPG Sound Pack/battle/swing.wav",
	"hit": "res://_host/assets/audio/sfx/Helton Yan's Pixel Combat - Single Files/DSGNImpt_MELEE-Homerunner_HY_PC-001.wav",
	"player_damage": "res://_host/assets/audio/sfx/Minifantasy_Dungeon_SFX/11_human_damage_1.wav",
	"enemy_death": "res://_host/assets/audio/sfx/Helton Yan's Pixel Combat - Single Files/DSGNImpt_EXPLOSION-Eruption_HY_PC-001.wav",
	"door_open": "res://_host/assets/audio/sfx/Minifantasy_Dungeon_SFX/05_door_open_1.mp3",
	"door_close": "res://_host/assets/audio/sfx/Minifantasy_Dungeon_SFX/06_door_close_1.mp3",
	"chest_open": "res://_host/assets/audio/sfx/Minifantasy_Dungeon_SFX/01_chest_open_1.wav",
	"coin": "res://_host/assets/audio/sfx/RPG Sound Pack/inventory/coin.wav",
	"victory": "res://_host/assets/audio/sfx/RPG Sound Pack/misc/random6.wav",
	"defeat": "res://_host/assets/audio/sfx/RPG Sound Pack/misc/random1.wav",
	"flee": "res://_host/assets/audio/sfx/RPG Sound Pack/misc/random3.wav",
	"magic": "res://_host/assets/audio/sfx/RPG Sound Pack/battle/magic1.wav",
}

var _sfx_stream_cache: Dictionary = {}


## ============================================
## SFX PLAYBACK -- GLOBAL (UI, non-spatial)
## ============================================
func play_sfx_by_name(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := _get_sfx_stream(sfx_name)
	if stream:
		play_sfx(stream, volume_db, pitch_scale)


func _get_sfx_stream(sfx_name: String) -> AudioStream:
	if _sfx_stream_cache.has(sfx_name):
		return _sfx_stream_cache[sfx_name]
	if not DEFAULT_SFX.has(sfx_name):
		push_warning("[AudioService] Unknown SFX name: " + sfx_name)
		return null
	var path: String = DEFAULT_SFX[sfx_name]
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path) as AudioStream
		_sfx_stream_cache[sfx_name] = s
		return s
	return null


func play_sfx(sound: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sound:
		push_warning("[AudioService] Attempted to play null sound!")
		return
	var player := _get_free_sfx_player()
	if player:
		player.stream = sound
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.play()
	else:
		push_warning("[AudioService] No free global SFX player!")


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in sfx_pool:
		if not player.playing:
			return player
	return null


static func create_spatial_sfx_player(parent: Node, max_distance: float = 1000.0, attenuation: float = 1.5) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.bus = BUS_SFX
	player.max_distance = max_distance
	player.attenuation = attenuation
	parent.add_child(player)
	return player


static func play_spatial_sfx(player: AudioStreamPlayer2D, sound: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not player or not sound:
		return
	player.stream = sound
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


## ============================================
## MUSIC PLAYBACK
## ============================================
func play_music(track_name: String, _fade_time: float = 1.0) -> void:
	var stream := _get_music_stream(track_name)
	if stream == null:
		push_warning("[AudioService] Track not found: %s" % track_name)
		return

	if current_track == track_name and music_player.playing:
		return

	var is_battle_track := track_name.begins_with("boss_") or track_name.begins_with("battle")
	var was_battle_track := current_track.begins_with("boss_") or current_track.begins_with("battle")

	# Save previous_track only when entering battle/boss from normal exploration/menu
	if is_battle_track:
		if not was_battle_track and current_track != "":
			previous_track = current_track
	else:
		if not was_battle_track and current_track != "":
			previous_track = current_track

	current_track = track_name
	music_player.stream = stream
	music_player.volume_db = 0.0
	music_player.play()
	music_changed.emit(track_name)


func start_boss_music(boss_name: String, fade_time: float = 0.5) -> void:
	var boss_track := boss_name
	if not music_track_paths.has(boss_track):
		boss_track = "boss_%s" % boss_name
	if not music_track_paths.has(boss_track):
		boss_track = "battle_boss"
	if not music_track_paths.has(boss_track):
		boss_track = "battle"
	play_music(boss_track, fade_time)


func return_to_previous_track(fade_time: float = 1.0) -> void:
	if previous_track != "" and music_track_paths.has(previous_track):
		play_music(previous_track, fade_time)
	else:
		stop_music(fade_time)


func end_boss_music(fade_time: float = 2.0, return_to_previous: bool = true) -> void:
	if return_to_previous:
		return_to_previous_track(fade_time)
	else:
		stop_music(fade_time)


func stop_music(fade_time: float = 1.0) -> void:
	if music_player.playing:
		var tween := create_tween()
		tween.tween_method(_set_music_player_volume, music_player.volume_db, -80.0, fade_time)
		await tween.finished
		music_player.stop()
		current_track = ""


func _set_music_player_volume(volume: float) -> void:
	music_player.volume_db = volume


## ============================================
## AMBIENCE
## ============================================
func play_ambience(sound: AudioStream, fade_time: float = 2.0) -> void:
	if not sound:
		return
	if ambience_player.playing:
		var fade_out := create_tween()
		fade_out.tween_property(ambience_player, "volume_db", -80.0, fade_time * 0.5)
		await fade_out.finished
	ambience_player.stream = sound
	ambience_player.play()
	var fade_in := create_tween()
	fade_in.tween_property(ambience_player, "volume_db", -20.0, fade_time * 0.5)


func stop_ambience(fade_time: float = 1.0) -> void:
	if ambience_player.playing:
		var tween := create_tween()
		tween.tween_property(ambience_player, "volume_db", -80.0, fade_time)
		await tween.finished
		ambience_player.stop()


## ============================================
## VOLUME CONTROL
## ============================================
func _apply_master_volume() -> void:
	var bus_index := AudioServer.get_bus_index(BUS_MASTER)
	if bus_index == -1:
		return
	if is_muted or master_volume <= 0.0001:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume))


func _apply_music_volume() -> void:
	var bus_index := AudioServer.get_bus_index(BUS_MUSIC)
	if bus_index == -1:
		return
	if is_muted or music_volume <= 0.0001:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(music_volume))


func _apply_sfx_volume() -> void:
	var bus_index := AudioServer.get_bus_index(BUS_SFX)
	if bus_index == -1:
		return
	if is_muted or sfx_volume <= 0.0001:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(sfx_volume))


## ============================================
## SAVE/LOAD PREFERENCES
## ============================================
func save_audio_settings() -> void:
	var settings_service: Node = get_node_or_null("/root/SettingsService")
	if settings_service and settings_service.has_method("set_bus_volume"):
		settings_service.set_bus_volume(BUS_MASTER, master_volume, false)
		settings_service.set_bus_volume(BUS_MUSIC, music_volume, false)
		settings_service.set_bus_volume(BUS_SFX, sfx_volume, true)
		return
	var settings := {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"master_volume": master_volume,
		"is_muted": is_muted,
	}
	var all_preferences := _load_preferences()
	all_preferences["audio"] = settings
	var file := FileAccess.open(PREFERENCES_PATH, FileAccess.WRITE)
	if file:
		file.store_var(all_preferences)
		file.close()
	else:
		push_error("[AudioService] Failed to save preferences!")


func load_audio_settings() -> void:
	var settings_service: Node = get_node_or_null("/root/SettingsService")
	if settings_service and settings_service.has_method("get_bus_volume"):
		master_volume = settings_service.get_bus_volume(BUS_MASTER)
		music_volume = settings_service.get_bus_volume(BUS_MUSIC)
		sfx_volume = settings_service.get_bus_volume(BUS_SFX)
		return
	var all_preferences := _load_preferences()
	if all_preferences.has("audio"):
		var audio_settings: Dictionary = all_preferences["audio"]
		music_volume = audio_settings.get("music_volume", 0.8)
		sfx_volume = audio_settings.get("sfx_volume", 1.0)
		master_volume = audio_settings.get("master_volume", 1.0)
		is_muted = audio_settings.get("is_muted", false)


func _load_preferences() -> Dictionary:
	if FileAccess.file_exists(PREFERENCES_PATH):
		var file := FileAccess.open(PREFERENCES_PATH, FileAccess.READ)
		if file:
			var data: Variant = file.get_var()
			file.close()
			if typeof(data) == TYPE_DICTIONARY:
				return data
	return {}
