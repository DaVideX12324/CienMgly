extends RefCounted
class_name InputBinds

## Zmienione klawisze akcji modułów (zakładka „Sterowanie” w opcjach).
## Zapis per moduł: SettingsService.set_module(<id>, "binds", {akcja: [physical_keycode, ...]}) — tylko akcje,
## których klawisze różnią się od domyślnych; najwyżej SLOTS klawiszy na akcję. Domyślne = klawisze akcji
## z ProjectSettings (input/<akcja>). Nakładane na InputMap przy starcie (SettingsService) i po starcie modułu
## (ModuleHost) — moduł może dopisywać własne domyślne klawisze (BitBomber: _ensure_key_action).
## Zdarzenia inne niż klawiatura (pad, mysz) zostają bez zmian.

const SLOTS := 2
const SETTING_KEY := "binds"


## Klawisze akcji z InputMap (physical keycode; zdarzenie z samym keycode — keycode, dla liter / cyfr
## w układzie US to te same wartości), bez powtórzeń, w kolejności zdarzeń.
static func get_keys(action: String) -> Array[int]:
	var out: Array[int] = []
	if not InputMap.has_action(action):
		return out
	for event in InputMap.action_get_events(action):
		var code := _event_code(event)
		if code != KEY_NONE and not out.has(code):
			out.append(code)
	return out


## Domyślne klawisze akcji z project.godot.
static func default_keys(action: String) -> Array[int]:
	var out: Array[int] = []
	var setting: Variant = ProjectSettings.get_setting("input/" + action)
	if setting is Dictionary:
		for event in (setting as Dictionary).get("events", []):
			var code := _event_code(event)
			if code != KEY_NONE and not out.has(code):
				out.append(code)
	return out


## Zastępuje klawisze akcji w InputMap (zdarzenia spoza klawiatury zostają).
static func set_keys(action: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = code as Key
		InputMap.action_add_event(action, event)


## Nakłada zapisane klawisze modułu na InputMap.
static func apply_module(settings: Node, module_id: String) -> void:
	if settings == null:
		return
	var binds: Variant = settings.call("get_module", module_id, SETTING_KEY, {})
	if not (binds is Dictionary):
		return
	for action in binds:
		var keys: Array[int] = []
		for code in binds[action]:
			keys.append(int(code))
		set_keys(str(action), keys)


## Zapisuje klawisze podanych akcji modułu (tylko te różne od domyślnych).
static func save_module(settings: Node, module_id: String, actions: Array) -> void:
	var binds := {}
	for action in actions:
		var keys := get_keys(str(action))
		if keys != default_keys(str(action)):
			binds[str(action)] = keys
	settings.call("set_module", module_id, SETTING_KEY, binds)


## Przywraca domyślne klawisze akcji modułu i usuwa zapis.
static func reset_module(settings: Node, module_id: String, actions: Array) -> void:
	for action in actions:
		set_keys(str(action), default_keys(str(action)))
	settings.call("set_module", module_id, SETTING_KEY, {})


## Nazwa klawisza w bieżącym układzie klawiatury, po polsku / krócej.
static func key_name(code: int) -> String:
	var label := DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	var name := OS.get_keycode_string(label if label != KEY_NONE else code as Key)
	var names := {"Space": "Spacja", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Escape": "Esc",
		"Backspace": "Backspace", "Kp Enter": "Num Enter", "Kp Add": "Num +", "Kp Subtract": "Num -",
		"Kp Multiply": "Num *", "Kp Divide": "Num /", "Kp Period": "Num ,"}
	if names.has(name):
		return names[name]
	if name.begins_with("Kp "):
		return "Num " + name.substr(3)
	return name


static func _event_code(event: Variant) -> int:
	if not (event is InputEventKey):
		return KEY_NONE
	var k := event as InputEventKey
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
