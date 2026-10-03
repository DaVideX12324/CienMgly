extends Node
## Przejście aktywowane klawiszem interakcji (LevelPortal w trybie klawisza, prośba usera 2026-10-04 — np.
## drabina w ściekach, gdzie nie ma oczywistego końca pokoju). Dziecko obszaru przejścia: gracz w obszarze ->
## podpowiedź „[E] …” (InteractPrompt nad środkiem kształtu obszaru), wciśnięcie „interact” -> przejście.

const InteractPromptScript = preload("../ui/interact_prompt.gd")

var on_enter: Callable
## Węzeł, nad którym stoi podpowiedź (kształt kolizji obszaru — jego środek, nie pozycja Area2D).
var prompt_target: Node2D
var prompt_text := "Przejdź"
var in_range := false


func set_in_range(value: bool) -> void:
	in_range = value
	if not is_instance_valid(prompt_target):
		return
	if value:
		InteractPromptScript.request(prompt_target, prompt_text)
	else:
		InteractPromptScript.release(prompt_target)


func _unhandled_input(event: InputEvent) -> void:
	if not in_range or not event.is_action_pressed(InteractPromptScript.ACTION):
		return
	get_viewport().set_input_as_handled()
	set_in_range(false)
	on_enter.call()


func _exit_tree() -> void:
	if in_range and is_instance_valid(prompt_target):
		InteractPromptScript.release(prompt_target)
