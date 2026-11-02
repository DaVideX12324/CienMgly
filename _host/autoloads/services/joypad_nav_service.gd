extends Node

## Gałka pada w UI: Godot traktuje każde drgnięcie osi (InputEventJoypadMotion) jako nowe wciśnięcie ui_*, więc fokus
## przeskakuje o wiele pól. Tu ruchy osi ui_* są pochłaniane, a kierunek gałki zamieniany na pojedyncze kroki
## z powtarzaniem przy przytrzymaniu (jak klawiatura). Stan Input (get_vector w grze) zostaje nietknięty.
## Pochłaniane są też osie akcji ruchu modułów (move_*) — menu modułów czytają je jako zdarzenia.
## Domyślne ui_* Godota nie mają przycisków pada — _ready dopisuje A / B i krzyżak.

const ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right",
	&"move_up", &"move_down", &"move_left", &"move_right"]
const PAD_BUTTONS := {&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B, &"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN, &"ui_left": JOY_BUTTON_DPAD_LEFT, &"ui_right": JOY_BUTTON_DPAD_RIGHT}
const DEADZONE := 0.5
## Przytrzymanie kierunku (gałka, krzyżak, strzałki, WASD): pojedynczy krok, po REPEAT_DELAY s przewijanie.
const REPEAT_DELAY := 1.0
const REPEAT_RATE := 0.12
## Przewijanie prawą gałką (px/s przy pełnym wychyleniu).
const SCROLL_SPEED := 900.0

var _held: StringName = &""
var _timer := 0.0
## Trzymane klawisze / przyciski kierunków (id zdarzenia -> akcja ui_*) — z surowych zdarzeń, nie ze stanu akcji
## (sztuczne kroki z _press go zmieniają).
var _raw_held := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Zaznaczenie padem / klawiaturą poza widocznym obszarem listy — lista przewija się do niego.
	get_viewport().gui_focus_changed.connect(_follow_focus)
	# _input idzie od ostatniego węzła drzewa — serwis trzyma się na końcu korzenia, żeby pochłaniać gałkę przed
	# menu z własnym _input (pauza, sklep, ...).
	get_tree().root.child_entered_tree.connect(func(n: Node) -> void:
		if n != self and n.get_parent() == get_tree().root:
			get_tree().root.move_child.call_deferred(self, -1))
	for action: StringName in PAD_BUTTONS:
		var ev := InputEventJoypadButton.new()
		ev.device = -1
		ev.button_index = PAD_BUTTONS[action]
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_raw_held.clear()


func _input(event: InputEvent) -> void:
	_track_raw(event)
	# Ruch gałki i powtórzenia (echo) klawiszy pochłaniane — kroki i przewijanie robi _process.
	if not (event is InputEventJoypadMotion or event.is_echo()):
		return
	for a in ACTIONS:
		if event.is_action(a):
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	_scroll_with_right_stick(delta)
	var stick := _stick_action()
	var dir := stick if stick != &"" else _held_button_action()
	if dir != _held:
		_held = dir
		_timer = REPEAT_DELAY
		if stick != &"":  # klawisz / krzyżak dał już pierwszy krok sam
			_press(dir)
		return
	if dir == &"":
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REPEAT_RATE
		_press(dir)


func _follow_focus(c: Control) -> void:
	var n: Node = c.get_parent()
	while n != null:
		if n is ScrollContainer:
			(n as ScrollContainer).ensure_control_visible.call_deferred(c)
			return
		n = n.get_parent()


## Prawa gałka przewija listę przy fokusie: najbliższy przodek ScrollContainer, inaczej pierwsza przewijalna
## lista / tekst (ScrollContainer, RichTextLabel) w scenie fokusu (np. okno „Co nowego”).
func _scroll_with_right_stick(delta: float) -> void:
	var v := 0.0
	for pad in Input.get_connected_joypads():
		var y := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		if absf(y) > absf(v):
			v = y
	if absf(v) < DEADZONE * 0.5:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		return
	var bar := _scroll_bar_for(focus)
	if bar != null:
		bar.value += v * SCROLL_SPEED * delta


func _scroll_bar_for(focus: Control) -> VScrollBar:
	var n: Node = focus.get_parent()
	while n != null:
		if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
			return (n as ScrollContainer).get_v_scroll_bar()
		n = n.get_parent()
	var root: Node = focus.owner if focus.owner != null else focus.get_parent()
	if root == null:
		return null
	for c in root.find_children("*", "Control", true, false):
		if not (c as Control).is_visible_in_tree():
			continue
		var bar: VScrollBar = null
		if c is ScrollContainer:
			bar = (c as ScrollContainer).get_v_scroll_bar()
		elif c is RichTextLabel:
			bar = (c as RichTextLabel).get_v_scroll_bar()
		if bar != null and bar.max_value - bar.page > 0.0:
			return bar
	return null


## Kierunek trzymany klawiszem / krzyżakiem (ui_* albo move_*) jako akcja ui_* albo "".
func _held_button_action() -> StringName:
	for id in _raw_held:
		return _raw_held[id]
	return &""


func _track_raw(event: InputEvent) -> void:
	var id := ""
	if event is InputEventKey:
		var k := event as InputEventKey
		id = "k%d" % (k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	elif event is InputEventJoypadButton:
		id = "j%d_%d" % [event.device, (event as InputEventJoypadButton).button_index]
	if id == "" or event.is_echo():
		return
	if not event.is_pressed():
		_raw_held.erase(id)
		return
	for a in ACTIONS:
		if InputMap.has_action(a) and event.is_action(a):
			_raw_held[id] = StringName("ui_" + str(a).get_slice("_", 1))
			return


## Kierunek gałki ponad martwą strefą (dominująca oś) albo "" — tylko z osi, przyciski krzyżaka działają po staremu.
func _stick_action() -> StringName:
	var best: StringName = &""
	var best_v := DEADZONE
	for pad in Input.get_connected_joypads():
		var x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		for c in [[-y, &"ui_up"], [y, &"ui_down"], [-x, &"ui_left"], [x, &"ui_right"]]:
			if c[0] > best_v:
				best_v = c[0]
				best = c[1]
	return best


func _press(action: StringName) -> void:
	if action == &"":
		return
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
