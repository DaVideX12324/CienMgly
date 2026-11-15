extends "door.gd"

## Drzwi z kłódką: zamknięte, dopóki nie ma flagi fabularnej `required_flag` (np. pokonany strażnik polany). Przy
## podejściu podpowiedź `locked_key` zamiast otwarcia; po zdobyciu flagi kłódka (węzeł Lock) znika i drzwi działają
## jak zwykłe. Zapis z flagą = drzwi od razu bez kłódki.

const BossGate = preload("../maps/boss_gate.gd")
const InteractPromptScript = preload("../ui/interact_prompt.gd")

@export var required_flag: String = "boss:tutorial_area"
## Klucz i18n podpowiedzi przy zamkniętych drzwiach.
@export var locked_key: String = "gate.tutorial_locked"

var _locked := true


func _ready() -> void:
	super._ready()
	_set_locked(not BossGate.is_open(self, required_flag))
	var lsm := BossGate.singleton(self, "LevelStateManager")
	if _locked and lsm and lsm.has_signal("story_flag_changed"):
		lsm.story_flag_changed.connect(_on_story_flag_changed)


func _set_locked(locked: bool) -> void:
	_locked = locked
	var lock := get_node_or_null("Lock") as CanvasItem
	if lock:
		lock.visible = locked


func _on_story_flag_changed(flag: String, value: bool) -> void:
	if flag != required_flag or not value or not _locked:
		return
	_set_locked(false)
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("chest_open")
	if _inside > 0:   # drużyna stoi przy drzwiach — otwierają się od razu
		InteractPromptScript.release(self)
		$AnimationPlayer.play("Open")


func _on_player_detection_body_entered(body: Node2D) -> void:
	if not _locked:
		super._on_player_detection_body_entered(body)
		return
	if QuizRpgPartyMember.is_member(body):
		_inside += 1
		InteractPromptScript.request(self, QuizRpgI18n.t(locked_key, "Zamknięte"))


func _on_player_detection_body_exited(body: Node2D) -> void:
	if not _locked:
		super._on_player_detection_body_exited(body)
		return
	if QuizRpgPartyMember.is_member(body):
		_inside = maxi(_inside - 1, 0)
		if _inside == 0:
			InteractPromptScript.release(self)


## Podpowiedź nad drzwiami (InteractPrompt).
func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -36)
