extends Node

## Nawigacja przez bramy (GatePlanner): kolce bramy są przeszkodą w siatce nawigacji, więc wrogowie nie przechodzą
## przez zamkniętą bramę. Po otwarciu (GateState.open_gate -> call_group("gate:<id>", "open")) kawałki siatki z tą
## bramą są wypiekane od nowa bez kolców wszystkich otwartych bram — wrogowie mogą przejść. Bramy otwarte w zapisie
## gry: przebudowa od razu przy wczytaniu poziomu.

const NavOutlinesScript = preload("../generation/navigation/nav_outlines.gd")
const MapGeneratorBaseScript = preload("../generation/map_generator_base.gd")
const GateStateScript = preload("../interactables/gate_state.gd")
const BARRIER_ID := &"gate_barrier"

var _result = null
var _nav: NavigationRegion2D = null
var _opened := {}   # id bramy -> true


## Węzeł w grupie "gate:<id>" — open() z GateState.open_gate przekazuje id bramy do GateNav.
class GateLink extends Node:
	var gate_id := ""
	var nav: Node = null

	func open() -> void:
		if nav != null:
			nav.open_gate(gate_id)


func setup(result, nav: NavigationRegion2D) -> void:
	_result = result
	_nav = nav
	if result == null or result.objects == null or nav == null:
		return
	var ids := {}
	for pl in result.objects.placements:
		if pl.def.id == BARRIER_ID and not pl.link.is_empty():
			ids[pl.link] = true
	var keys: Array[Vector2i] = []
	for id: String in ids:
		var link := GateLink.new()
		link.name = "Gate_" + id
		link.gate_id = id
		link.nav = self
		link.add_to_group("gate:" + id)
		add_child(link)
		if GateStateScript.is_gate_open(self, id):
			_opened[id] = true
			for k in NavOutlinesScript.chunks_of_link(result, id):
				if not keys.has(k):
					keys.append(k)
	if not keys.is_empty():
		_rebake(keys)


func open_gate(id: String) -> void:
	if _opened.has(id) or _result == null:
		return
	_opened[id] = true
	_rebake(NavOutlinesScript.chunks_of_link(_result, id))


func _rebake(keys: Array[Vector2i]) -> void:
	var polys: Dictionary = NavOutlinesScript.rebake_chunks(_result, keys, _opened)
	for k: Vector2i in polys:
		var node_name := MapGeneratorBaseScript.chunk_name(k)
		var chunk := _nav.get_node_or_null(node_name) as NavigationRegion2D
		var np: NavigationPolygon = polys[k]
		if np == null:
			continue
		if chunk == null:
			chunk = NavigationRegion2D.new()
			chunk.name = node_name
			_nav.add_child(chunk)
		chunk.navigation_polygon = np
