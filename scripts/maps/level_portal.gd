extends RefCounted
## Obszary przejścia między poziomami (enter_next_level / enter_previous_level) i punkty pojawienia się.
## Gracz nie pojawia się w obszarze przejścia, tylko przy markerze odsuniętym od niego (prośba usera
## 2026-10-04): na mapach generowanych `Spawn` (przyjście z poprzedniego poziomu) i FROM_NEXT_SPAWN (powrót
## z następnego) kilka kratek od obszaru (MapGeneratorBase.arrival_cell), w scenach ręcznych — marker w Spawns.
## Na wszelki wypadek: obszar, w którym gracz stoi zaraz po wczytaniu, działa dopiero po jego opuszczeniu.
## Tryb klawisza (use_key albo metadana obszaru `portal_use_key`): przejście dopiero po „interact” (E) w obszarze,
## z podpowiedzią `portal_prompt` (domyślnie „Przejdź”) — PortalKeyListener.

const NEXT_AREA := "enter_next_level"
const PREVIOUS_AREA := "enter_previous_level"
## Marker przy wyjściu poziomu generowanego — tu trafia gracz wracający z następnego poziomu.
const FROM_NEXT_SPAWN := "FromNext"
## Tyle klatek fizyki po podpięciu obszar czeka (gracz zdąży stanąć na spawnie), zanim się uzbroi.
const ARM_PHYSICS_FRAMES := 5
const META_USE_KEY := &"portal_use_key"
const META_PROMPT := &"portal_prompt"
const DEFAULT_PROMPT := "Przejdź"
const PortalKeyListener = preload("portal_key_listener.gd")


## Podpina `on_enter` pod obszar. Wołać po dodaniu poziomu do drzewa (call_deferred albo po generacji).
## use_key / prompt: tryb klawisza (metadane obszaru mają pierwszeństwo — ustawiane w edytorze sceny).
static func connect_area(area: Area2D, on_enter: Callable, use_key: bool = false, prompt: String = "") -> void:
	if area == null or area.has_meta(&"level_portal"):
		return
	area.set_meta(&"level_portal", true)
	if bool(area.get_meta(META_USE_KEY, use_key)):
		_connect_key(area, on_enter, str(area.get_meta(META_PROMPT, prompt)))
		return
	var armed := [false]
	area.body_exited.connect(func(body: Node2D) -> void:
		if is_player(body):
			armed[0] = true)
	area.body_entered.connect(func(body: Node2D) -> void:
		if is_player(body) and armed[0]:
			on_enter.call())
	_arm_when_clear(area, armed)


static func _connect_key(area: Area2D, on_enter: Callable, prompt: String) -> void:
	var listener: Node = PortalKeyListener.new()
	listener.name = "PortalKey"
	listener.on_enter = on_enter
	listener.prompt_text = prompt if not prompt.is_empty() else DEFAULT_PROMPT
	var shape := area.get_node_or_null("CollisionShape2D") as Node2D
	listener.prompt_target = shape if shape else area
	area.add_child(listener)
	area.body_entered.connect(func(body: Node2D) -> void:
		if is_player(body):
			listener.set_in_range(true))
	area.body_exited.connect(func(body: Node2D) -> void:
		if is_player(body):
			listener.set_in_range(false))
	# Gracz już w obszarze (pojawił się w nim) — podpowiedź od razu.
	for body in area.get_overlapping_bodies():
		if is_player(body):
			listener.set_in_range(true)


## Uzbraja obszar po ARM_PHYSICS_FRAMES klatkach fizyki, chyba że gracz w nim stoi (wtedy body_exited).
static func _arm_when_clear(area: Area2D, armed: Array) -> void:
	for i in ARM_PHYSICS_FRAMES:
		await area.get_tree().physics_frame
		if not is_instance_valid(area):
			return
	for body in area.get_overlapping_bodies():
		if is_player(body):
			return
	armed[0] = true


## Marker `marker_name` w węźle Spawns poziomu (tworzy brakujące węzły), w pozycji lokalnej `pos`.
static func place_marker(level: Node2D, marker_name: String, pos: Vector2) -> void:
	var spawns := level.get_node_or_null("Spawns") as Node2D
	if spawns == null:
		spawns = Node2D.new()
		spawns.name = "Spawns"
		level.add_child(spawns)
	var marker := spawns.get_node_or_null(marker_name) as Marker2D
	if marker == null:
		marker = Marker2D.new()
		marker.name = marker_name
		spawns.add_child(marker)
	marker.global_position = level.to_global(pos)


static func place_from_next_marker(level: Node2D, pos: Vector2) -> void:
	place_marker(level, FROM_NEXT_SPAWN, pos)


static func is_player(body: Node2D) -> bool:
	return body != null and (body.is_in_group("player") or body.name == "Player")
