extends RefCounted

## Ekran ładowania na czas powrotu z gry do menu głównego (ekran śmierci, menu pauzy). Węzeł wisi na korzeniu drzewa
## (przeżywa wymianę scen), pasek postępu jest umowny — ekran tylko zasłania przełączenie sceny. Przejście między
## Artefaktem Wiedzy a modułem ma własny ekran na poziomie hosta (scripts/core/module_transition.gd).

const LoadingScreenScene = preload("../../scenes/ui/loading_screen.tscn")
const MENU_HOLD_SEC := 0.3


## Zasłania ekran (nad wszystkim, działa w pauzie). title = podpis nad paskiem, location = duży napis.
static func cover(tree: SceneTree, title: String, location: String, progress: float = 0.15, stage: String = "") -> Node:
	var overlay := LoadingScreenScene.instantiate()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.title = title
	overlay.location = location
	tree.root.add_child(overlay)
	overlay.set_progress(progress, stage)
	return overlay


## Po `hold` s dociąga pasek do końca i zdejmuje ekran.
static func uncover(tree: SceneTree, overlay: Node, hold: float, stage: String = "") -> void:
	if is_instance_valid(overlay):
		overlay.set_progress(0.85, stage)
	await tree.create_timer(hold, true).timeout
	if is_instance_valid(overlay):
		overlay.close()
