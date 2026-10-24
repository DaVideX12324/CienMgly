class_name QuizRpgI18n
extends RefCounted

## Tłumaczenia tekstów gry: płaskie słowniki klucz -> tekst w resources/i18n/<język>.json (np. "skill.onslaught.name", "skill.onslaught.desc").
## Deleguje operacje do globalnego serwisu I18nService.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const FALLBACK_LANG := "en"

static var _registered := false


## Rejestruje katalog słowników w I18nService (idempotentnie).
static func register() -> void:
	if _registered:
		return
	var svc := _get_service()
	if svc != null:
		svc.call("register_dir", QuizRpgPaths.path("resources/i18n/"))
		_registered = true


static func _get_service() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root:
		return main_loop.root.get_node_or_null("I18nService")
	return null


## Bieżący język gry ("pl" / "en"; bez serwisu — "pl").
static func language() -> String:
	var svc := _get_service()
	return str(svc.call("get_current_language")) if svc != null and svc.has_method("get_current_language") else "pl"


static func t(key: String, fallback: String = "") -> String:
	register()
	var svc := _get_service()
	if svc != null:
		return str(svc.call("t", key, fallback))
	return fallback if fallback != "" else key


static func tf(key: String, args: Dictionary, fallback: String = "") -> String:
	register()
	var svc := _get_service()
	if svc != null:
		return str(svc.call("tf", key, args, fallback))
	return (fallback if fallback != "" else key).format(args)


static func plural(key_base: String, n: int, args: Dictionary = {}) -> String:
	register()
	var svc := _get_service()
	if svc != null:
		return str(svc.call("plural", key_base, n, args))
	var fmt_args := args.duplicate()
	fmt_args["n"] = n
	return ("%s.many" % key_base).format(fmt_args)


## Czy klucz istnieje w wybranym języku albo w en (t() zwraca wtedy tłumaczenie, a nie klucz).
static func has(key: String) -> bool:
	register()
	var svc := _get_service()
	if svc != null:
		return bool(svc.call("has", key))
	return false


## Klucz nazwy umiejętności z pliku zasobu: "skill.<nazwa pliku .tres bez rozszerzenia>.name".
static func skill_name_key(res: Resource) -> String:
	return "skill.%s.name" % _source_base(res)


## Klucz opisu umiejętności: "skill.<nazwa pliku .tres>.desc".
static func skill_desc_key(res: Resource) -> String:
	return "skill.%s.desc" % _source_base(res)


## Nazwa pliku zasobu bez rozszerzenia; kopia skilla na wyższym tierze (QuizRpgSkillData.at_tier) — z meta source_path.
static func _source_base(res: Resource) -> String:
	var p := res.resource_path if res.resource_path != "" else str(res.get_meta(&"source_path", ""))
	return p.get_file().get_basename()


## Klucz tekstu z logu walki użycia umiejętności wroga: "skill.<plik .tres>.log" ({enemy}, {skill} jak w log_text).
static func skill_log_key(res: Resource) -> String:
	return "skill.%s.log" % _source_base(res)


## Klucze nazwy i opisu statusu z pliku zasobu: "status.<plik>.name" / "status.<plik>.desc".
static func status_name_key(res: Resource) -> String:
	return "status.%s.name" % res.resource_path.get_file().get_basename()


static func status_desc_key(res: Resource) -> String:
	return "status.%s.desc" % res.resource_path.get_file().get_basename()


## Wymusza ponowne wczytanie słowników (po edycji JSON w edytorze / w testach).
static func reload() -> void:
	_registered = false
	register()
	var svc := _get_service()
	if svc != null:
		svc.call("reload")
