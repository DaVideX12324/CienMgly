extends RefCounted
## Obszary przejścia między poziomami (enter_next_level / enter_previous_level) i punkt, w którym gracz
## pojawia się po powrocie z następnego poziomu (marker FROM_NEXT_SPAWN przy wyjściu).
## Gracz, który pojawił się w obszarze po przejściu z drugiej strony, nie wraca od razu — obszar działa
## dopiero, gdy go opuści.

const NEXT_AREA := "enter_next_level"
const PREVIOUS_AREA := "enter_previous_level"
## Marker przy wyjściu poziomu — tu trafia gracz wracający z następnego poziomu.
const FROM_NEXT_SPAWN := "FromNext"


## Podpina `on_enter` pod obszar. arrival_spawn = nazwa spawnu leżącego w tym obszarze (dla wyjścia
## FROM_NEXT_SPAWN, dla wejścia — spawn, którym przychodzi się z poprzedniego poziomu). Wołać, gdy
## level_manager ma już ustawiony current_spawn_name (po add_child poziomu: call_deferred albo po generacji).
static func connect_area(area: Area2D, arrival_spawn: String, level_manager: Node, on_enter: Callable) -> void:
	if area == null or area.has_meta(&"level_portal"):
		return
	area.set_meta(&"level_portal", true)
	var arrived_here: bool = level_manager != null and str(level_manager.get("current_spawn_name")) == arrival_spawn
	var armed := [not arrived_here]
	area.body_exited.connect(func(body: Node2D) -> void:
		if is_player(body):
			armed[0] = true)
	area.body_entered.connect(func(body: Node2D) -> void:
		if is_player(body) and armed[0]:
			on_enter.call())


## Marker FROM_NEXT_SPAWN w węźle Spawns poziomu (tworzy brakujące węzły), w pozycji lokalnej `pos`.
static func place_from_next_marker(level: Node2D, pos: Vector2) -> void:
	var spawns := level.get_node_or_null("Spawns") as Node2D
	if spawns == null:
		spawns = Node2D.new()
		spawns.name = "Spawns"
		level.add_child(spawns)
	var marker := spawns.get_node_or_null(FROM_NEXT_SPAWN) as Marker2D
	if marker == null:
		marker = Marker2D.new()
		marker.name = FROM_NEXT_SPAWN
		spawns.add_child(marker)
	marker.global_position = level.to_global(pos)


static func is_player(body: Node2D) -> bool:
	return body != null and (body.is_in_group("player") or body.name == "Player")
