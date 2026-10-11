extends Resource
class_name QuizRpgItemData

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_enum("item", "hand", "part", "key") var category: String = "item"
@export var stackable: bool = true
@export_range(1, 999, 1) var max_stack: int = 99
@export var consumable: bool = true
@export var usable_in_menu: bool = true
@export var usable_in_combat: bool = true
@export var equip_slot: String = ""
## Rodzaj broni (slot "weapon"): umiejętności z required_weapon_type działają tylko z broniami tego rodzaju ("none" = bez rodzaju).
@export_enum("none", "sword", "dagger", "axe", "spear", "mace", "staff", "bow") var weapon_type: String = "none"
@export var heal_amount: int = 0
@export var sp_restore: int = 0
@export var tp_restore: int = 0
## Statusy zdejmowane przez przedmiot (np. "poison" — PlayerStats.STATUS_*).
@export var cure_statuses: PackedStringArray = []
@export var atk_bonus: int = 0
@export var def_bonus: int = 0
@export var mat_bonus: int = 0
@export var mdf_bonus: int = 0


const WEAPON_TYPE_NAMES := {"sword": "Miecz", "dagger": "Sztylet", "axe": "Topór", "spear": "Włócznia", "mace": "Buława", "staff": "Kostur", "bow": "Łuk"}


static func weapon_type_name(type_id: String) -> String:
	return str(WEAPON_TYPE_NAMES.get(type_id, type_id))


func get_effect_summary() -> String:
	var parts: Array[String] = []
	if heal_amount > 0:
		parts.append("+%d HP" % heal_amount)
	if sp_restore > 0:
		parts.append("+%d SP" % sp_restore)
	if tp_restore > 0:
		parts.append("+%d TP" % tp_restore)
	if cure_statuses.has("poison"):
		parts.append("leczy zatrucie")
	return ", ".join(parts)
