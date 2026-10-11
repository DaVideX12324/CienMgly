class_name QuizRpgI18n
extends RefCounted

## Tłumaczenia tekstów gry: płaskie słowniki klucz -> tekst w resources/i18n/<język>.json (np. "skill.onslaught.name").
## Język wybiera opcja „Język” w Motywie (QuizTheme.language()). Brak klucza w wybranym języku -> en -> tekst zapasowy
## (display_name z zasobu), więc nowe teksty można dopisywać stopniowo.

const DIR := "res://modules/quiz_rpg/resources/i18n/"
const FALLBACK_LANG := "en"

static var _cache: Dictionary = {}  # język -> słownik


static func t(key: String, fallback: String = "") -> String:
	var lang := QuizTheme.language()
	var dict := _dict(lang)
	if dict.has(key):
		return str(dict[key])
	if lang != FALLBACK_LANG:
		var en := _dict(FALLBACK_LANG)
		if en.has(key):
			return str(en[key])
	return fallback if fallback != "" else key


## Klucz nazwy umiejętności z pliku zasobu: "skill.<nazwa pliku .tres bez rozszerzenia>.name".
static func skill_name_key(res: Resource) -> String:
	return "skill.%s.name" % res.resource_path.get_file().get_basename()


## Wymusza ponowne wczytanie słowników (po edycji JSON w edytorze / w testach).
static func reload() -> void:
	_cache.clear()


static func _dict(lang: String) -> Dictionary:
	if _cache.has(lang):
		return _cache[lang]
	var d := {}
	var path := DIR + lang + ".json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
		else:
			push_warning("QuizRpgI18n: nieprawidłowy JSON: " + path)
	_cache[lang] = d
	return d
