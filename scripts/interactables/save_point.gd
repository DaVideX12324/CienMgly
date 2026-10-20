extends Area2D

## Punkt narzuconego zapisu (scena scenes/objects/save_point.tscn), np. przed point of no return (brama zamku): gracz
## wchodzi w strefę -> ostrzeżenie w oknie rozmowy, potem samo otwiera się menu pauzy na zakładce zapisu. Opcjonalna
## bariera (dziecko StaticBody2D „Barrier”) przepuszcza dopiero po zapisie. Zapis tylko ręczny poza tym (decyzja
## usera) — punkt nie zapisuje sam, tylko wymusza okno. Stan: flaga fabularna save_point:<point_id> (ustawiana przed
## zapisem, żeby trafiła do pliku; cofana, gdy gracz zamknie okno bez zapisu).

const DialogBox = preload("../ui/dialog_box.gd")

@export var point_id: String = "point_of_no_return"
@export var warning: PackedStringArray = [
	"Za tym miejscem nie będzie powrotu.",
	"Zapisz grę, zanim pójdziesz dalej.",
]
@export var warning_key: String = "save_point.warning"
## Po zapisie punkt już nie pyta (i bariera znika na stałe).
@export var once: bool = true

var _busy := false
var _saved := false

@onready var _barrier: StaticBody2D = get_node_or_null("Barrier") as StaticBody2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # czeka na zamknięcie menu pauzy (drzewo zapauzowane)
	body_entered.connect(_on_body_entered)
	call_deferred("_check_state")


func flag() -> String:
	return "save_point:" + point_id


func _check_state() -> void:
	if QuizRpgNpcContext.has_flag(self, flag()):
		_open_barrier()


func _open_barrier() -> void:
	if _barrier:
		for c in _barrier.get_children():
			if c is CollisionShape2D or c is CollisionPolygon2D:
				c.set_deferred("disabled", true)


func _on_body_entered(body: Node2D) -> void:
	if _busy or not (body.is_in_group("player") or body.name == "Player"):
		return
	if once and QuizRpgNpcContext.has_flag(self, flag()):
		return
	var gm := QuizRpgNpcContext.singleton(self, "GameManager")
	if gm and gm.has_method("is_exploring") and not gm.is_exploring():
		return
	_busy = true
	await _prompt()
	_busy = false


func _prompt() -> void:
	var lines := QuizRpgNpcContext.lines(warning, warning_key)
	if not lines.is_empty():
		await DialogBox.open(self, "", lines).finished
	var lsm := QuizRpgNpcContext.singleton(self, "LevelStateManager")
	var had := QuizRpgNpcContext.has_flag(self, flag())
	QuizRpgNpcContext.set_flag(self, flag())   # przed zapisem — trafia do pliku
	_saved = false
	var sm := QuizRpgNpcContext.singleton(self, "SaveManager")
	if sm and sm.has_signal("save_completed") and not sm.save_completed.is_connected(_on_saved):
		sm.save_completed.connect(_on_saved)
	get_tree().call_group(&"quiz_pause_menu", "open_save_menu")
	await get_tree().process_frame
	while _pause_open():
		await get_tree().process_frame
	if sm and sm.save_completed.is_connected(_on_saved):
		sm.save_completed.disconnect(_on_saved)
	if _saved:
		_open_barrier()
	elif not had and lsm and lsm.has_method("clear_story_flag"):
		lsm.clear_story_flag(flag())


func _on_saved(_slot: int) -> void:
	_saved = true


func _pause_open() -> bool:
	var pm := get_tree().get_first_node_in_group(&"quiz_pause_menu")
	return pm != null and pm.has_method("is_paused") and bool(pm.call("is_paused"))
