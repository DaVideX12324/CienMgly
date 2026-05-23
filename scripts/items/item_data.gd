extends Resource
class_name QuizRpgItemData

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var stackable: bool = true
@export_range(1, 999, 1) var max_stack: int = 99
@export var consumable: bool = true
@export var usable_in_menu: bool = true
@export var usable_in_combat: bool = true
@export var heal_amount: int = 0
@export var sp_restore: int = 0
@export var tp_restore: int = 0


func get_effect_summary() -> String:
	var parts: Array[String] = []
	if heal_amount > 0:
		parts.append("+%d HP" % heal_amount)
	if sp_restore > 0:
		parts.append("+%d SP" % sp_restore)
	if tp_restore > 0:
		parts.append("+%d TP" % tp_restore)
	return ", ".join(parts)
