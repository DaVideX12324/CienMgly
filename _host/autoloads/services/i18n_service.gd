extends Node

## Serwis tłumaczeń Artefaktu Wiedzy (I18nService).
## Zarządza płaskimi słownikami JSON dla hosta i modułów oraz tłumaczeniem scen przez TranslationServer.

signal language_changed(lang: String)

const SOURCE_LANG := "pl"
const FALLBACK_LANG := "en"

var _registered_dirs: Array[String] = []
var _dictionaries: Dictionary = {}  # lang: String -> Dictionary[String, String]
var _key_sources: Dictionary = {}   # key: String -> dir: String
var _current_translation: Translation = null
var _initialized := false


func _ready() -> void:
	_ensure_init()


## Jednorazowa inicjalizacja (też leniwie z t() / has(), bo w skryptach -s _ready autoloadu działa dopiero po _initialize).
func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	# Host: res://_host/resources/i18n/; wersja samodzielna modułu trzyma kopię słowników hosta w res://_host/.
	for dir in ["res://_host/resources/i18n/", "res://_host/resources/i18n/"]:
		if FileAccess.file_exists(dir + "pl.json"):
			register_dir(dir)
	var settings := _settings()
	if settings and settings.has_signal("language_changed") and not settings.language_changed.is_connected(_on_settings_language_changed):
		settings.language_changed.connect(_on_settings_language_changed)


## SettingsService względem korzenia drzewa (działa też w skryptach testowych uruchamianych przez -s, gdzie ścieżki /root/... nie).
func _settings() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SettingsService")
	return null


func _on_settings_language_changed(lang: String) -> void:
	_rebuild_scene_translations()
	language_changed.emit(lang)


func get_current_language() -> String:
	var settings := _settings()
	if settings and settings.has_method("get_language"):
		return str(settings.call("get_language"))
	return SOURCE_LANG


## Rejestruje katalog ze słownikami (pl.json, en.json) i przeładowuje zasoby.
func register_dir(dir: String) -> void:
	_ensure_init()
	var normalized := dir
	if not normalized.ends_with("/"):
		normalized += "/"
	if not normalized in _registered_dirs:
		_registered_dirs.append(normalized)
	reload()


## Zwraca tłumaczenie klucza (bieżący język -> en -> fallback -> klucz).
func t(key: String, fallback: String = "") -> String:
	_ensure_init()
	var lang := get_current_language()
	var dict_cur: Dictionary = _dictionaries.get(lang, {})
	if dict_cur.has(key):
		return str(dict_cur[key])
	if lang != FALLBACK_LANG:
		var dict_en: Dictionary = _dictionaries.get(FALLBACK_LANG, {})
		if dict_en.has(key):
			return str(dict_en[key])
	if fallback != "":
		return fallback
	return key


## Formatowane tłumaczenie z argumentami (t(key).format(args)).
func tf(key: String, args: Dictionary, fallback: String = "") -> String:
	return t(key, fallback).format(args)


## Czy klucz istnieje w słowniku bieżącego języka lub języka zapasowego.
func has(key: String) -> bool:
	_ensure_init()
	var lang := get_current_language()
	var dict_cur: Dictionary = _dictionaries.get(lang, {})
	if dict_cur.has(key):
		return true
	var dict_en: Dictionary = _dictionaries.get(FALLBACK_LANG, {})
	return dict_en.has(key)


## Tłumaczenie liczby mnogiej. Dobiera sufiks .one / .few / .many dla danego języka i formatuje {n}.
func plural(key_base: String, n: int, args: Dictionary = {}) -> String:
	var lang := get_current_language()
	var suffix := _get_plural_suffix(lang, n)
	var full_key := "%s.%s" % [key_base, suffix]
	var fmt_args := args.duplicate()
	fmt_args["n"] = n
	if has(full_key):
		return tf(full_key, fmt_args)
	var fallback_many := "%s.many" % key_base
	if has(fallback_many):
		return tf(fallback_many, fmt_args)
	return tf(key_base, fmt_args)


func _get_plural_suffix(lang: String, n: int) -> String:
	var abs_n := absi(n)
	if lang == "pl":
		if abs_n == 1:
			return "one"
		var mod10 := abs_n % 10
		var mod100 := abs_n % 100
		if mod10 >= 2 and mod10 <= 4 and not (mod100 >= 12 and mod100 <= 14):
			return "few"
		return "many"
	else:
		if abs_n == 1:
			return "one"
		return "many"


## Przeładowuje słowniki ze wszystkich zarejestrowanych katalogów.
func reload() -> void:
	_dictionaries.clear()
	_key_sources.clear()

	var languages := [SOURCE_LANG, FALLBACK_LANG]
	var settings := _settings()
	if settings and "LANGUAGES" in settings:
		var langs_variant: Variant = settings.LANGUAGES
		if langs_variant is Array:
			for item in langs_variant:
				if item is Dictionary and item.has("id"):
					var lid := str(item["id"])
					if not lid in languages:
						languages.append(lid)

	for lang in languages:
		_dictionaries[lang] = {}

	for dir in _registered_dirs:
		_load_dir(dir, languages)

	_rebuild_scene_translations()


func _load_dir(dir: String, languages: Array) -> void:
	for lang in languages:
		var path := dir.path_join("%s.json" % lang)
		if not FileAccess.file_exists(path):
			continue
		var file_text := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(file_text)
		if not (parsed is Dictionary):
			push_warning("I18nService: plik '%s' nie zawiera poprawnego słownika JSON" % path)
			continue
		var dict: Dictionary = parsed
		for key in dict.keys():
			var key_str := str(key)
			if _key_sources.has(key_str) and _key_sources[key_str] != dir:
				push_warning("I18nService: zduplikowany klucz '%s' w katalogu '%s' (wcześniej w '%s')" % [key_str, dir, _key_sources[key_str]])
			else:
				_key_sources[key_str] = dir
			_dictionaries[lang][key_str] = str(dict[key])


## Buduje obiekt Translation dla TranslationServer dla języków innych niż SOURCE_LANG (pl).
func _rebuild_scene_translations() -> void:
	if _current_translation != null:
		TranslationServer.remove_translation(_current_translation)
		_current_translation = null

	var lang := get_current_language()
	if lang == SOURCE_LANG:
		TranslationServer.set_locale(SOURCE_LANG)
		return

	var tr := Translation.new()
	tr.locale = lang

	var pl_dict: Dictionary = _dictionaries.get(SOURCE_LANG, {})
	var lang_dict: Dictionary = _dictionaries.get(lang, {})
	var en_dict: Dictionary = _dictionaries.get(FALLBACK_LANG, {})

	var pl_to_tr := {}
	var pl_to_key := {}

	for key in pl_dict.keys():
		var pl_text: String = str(pl_dict[key])
		var tr_text: String = str(lang_dict.get(key, en_dict.get(key, "")))
		if pl_text == "" or tr_text == "":
			continue

		if pl_to_tr.has(pl_text):
			if pl_to_tr[pl_text] != tr_text:
				push_warning("I18nService: ten sam polski tekst '%s' ma różne tłumaczenia w kluczach '%s' ('%s') i '%s' ('%s')" % [
					pl_text, pl_to_key[pl_text], pl_to_tr[pl_text], key, tr_text
				])
		else:
			pl_to_tr[pl_text] = tr_text
			pl_to_key[pl_text] = key
			tr.add_message(pl_text, tr_text)

	TranslationServer.add_translation(tr)
	_current_translation = tr
	TranslationServer.set_locale(lang)
