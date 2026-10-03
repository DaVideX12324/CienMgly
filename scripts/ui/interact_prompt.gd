extends CanvasLayer
## Podpowiedź „[E] Otwórz” nad obiektem, z którym można wejść w interakcję klawiszem (zgłoszenie usera
## 2026-10-04). Warstwa ekranowa gracza — ostra niezależnie od zoomu kamery. Obiekty zgłaszają się same:
## InteractPrompt.request(self, "Otwórz") / release(self) (skrzynie), a gracz zgłasza najbliższy obiekt ze swojej
## listy interakcji (drzwi z zagadką…). Przy kilku zgłoszonych pokazuje najbliższy graczowi; tylko podczas
## eksploracji. Klawisz z bieżących przypisań akcji „interact” (zmiana klawiszy w opcjach).

const QuizTheme = preload("quiz_theme.gd")
const GROUP := &"interact_prompt"
const ACTION := "interact"
const FONT_SIZE := 27
## Domyślna wysokość nad pozycją obiektu (świat), gdy obiekt nie podaje własnej (interaction_prompt_offset()).
const DEFAULT_OFFSET := Vector2(0, -22)

var _targets: Dictionary = {}  # Node2D -> tekst akcji
var _panel: PanelContainer
var _label: Label


## Zgłoszenie obiektu (np. gracz w zasięgu skrzyni). Bez gracza z podpowiedzią — nic się nie dzieje.
static func request(target: Node2D, action_text: String) -> void:
	if target.is_inside_tree():
		target.get_tree().call_group(GROUP, "set_target", target, action_text)


static func release(target: Node2D) -> void:
	if target.is_inside_tree():
		target.get_tree().call_group(GROUP, "clear_target", target)


func _ready() -> void:
	add_to_group(GROUP)
	layer = 4
	_panel = PanelContainer.new()
	_panel.theme_type_variation = QuizTheme.WINDOW
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)
	add_child(_panel)


func set_target(target: Node2D, action_text: String) -> void:
	_targets[target] = action_text


func clear_target(target: Node2D) -> void:
	_targets.erase(target)


func _process(_delta: float) -> void:
	var target := _closest_target()
	if target == null or not _is_exploring():
		_panel.visible = false
		return
	_label.text = "[%s] %s" % [_key_name(), _targets[target]]
	var offset: Vector2 = target.call("interaction_prompt_offset") if target.has_method("interaction_prompt_offset") else DEFAULT_OFFSET
	var screen: Vector2 = target.get_viewport().get_canvas_transform() * (target.global_position + offset)
	_panel.reset_size()
	_panel.position = (screen - Vector2(_panel.size.x * 0.5, _panel.size.y)).round()
	_panel.visible = true


func _closest_target() -> Node2D:
	var owner_pos: Vector2 = (get_parent() as Node2D).global_position if get_parent() is Node2D else Vector2.ZERO
	var best: Node2D = null
	var best_d := INF
	for t in _targets.keys():
		if not is_instance_valid(t) or not (t as Node2D).is_visible_in_tree():
			_targets.erase(t)
			continue
		var d := owner_pos.distance_squared_to((t as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


func _is_exploring() -> bool:
	var core := get_node_or_null("/root/CoreManager")
	var gm: Node = core.call("get_singleton", "GameManager") if core else null
	return gm == null or gm.call("is_exploring")


func _key_name() -> String:
	var keys := InputBinds.get_keys(ACTION)
	return InputBinds.key_name(keys[0]) if not keys.is_empty() else "?"
