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
## Klasy, które mogą założyć przedmiot (warrior / rogue / mage / priest); pusta lista = każda postać.
@export var allowed_classes: PackedStringArray = []
@export var heal_amount: int = 0
## Leczenie w ułamku maks. HP celu (0–1; mikstury procentowe tieru 3) — dodawane do heal_amount.
@export_range(0.0, 1.0, 0.05) var heal_percent: float = 0.0
@export var sp_restore: int = 0
## Odnowienie SP w ułamku maks. SP celu (0–1; etery procentowe tieru 3) — dodawane do sp_restore.
@export_range(0.0, 1.0, 0.05) var sp_percent: float = 0.0
@export var tp_restore: int = 0
## Statusy zdejmowane przez przedmiot (np. "poison" — PlayerStats.STATUS_*).
@export var cure_statuses: PackedStringArray = []
@export var atk_bonus: int = 0
@export var def_bonus: int = 0
@export var mat_bonus: int = 0
@export var mdf_bonus: int = 0
@export var agi_bonus: int = 0
## Sloty umiejętności (QuizRpgSkillSlots): zmiana budżetu (jednostki, może być ujemna) i maks. tieru członka, który to nosi.
@export var slot_budget: int = 0
@export var max_tier_bonus: int = 0
## Cena w sklepie (złoto); sprzedaż za połowę. 0 = nie do kupienia ani sprzedania (klucze, przedmioty fabularne).
@export var price: int = 0

@export_group("Ulepszenie u kowala")
## Broń z potencjałem (ekwipunek_szkic.md sekcje 4, 10): etap = osobny przedmiot; kowal (QuizRpgNpcUpgrade) zamienia ten
## przedmiot na `upgrade_to` za dukaty i opcjonalny materiał, gdy jest flaga fabularna (kowal „przypomina sobie”). Puste = bez ulepszenia.
@export var upgrade_to: String = ""
@export var upgrade_gold: int = 0
@export var upgrade_flag: String = ""
@export var upgrade_item_id: String = ""
@export_range(1, 99, 1) var upgrade_item_count: int = 1


## Cena odkupu przez sklep (połowa ceny, co najmniej 1 dla przedmiotów z ceną).
func sell_price() -> int:
	return maxi(price / 2, 1) if price > 0 else 0


## Czy przedmiot może założyć postać danej klasy.
func usable_by_class(class_id: String) -> bool:
	return allowed_classes.is_empty() or allowed_classes.has(class_id)


const WEAPON_TYPE_NAMES := {"sword": "Miecz", "dagger": "Sztylet", "axe": "Topór", "spear": "Włócznia", "mace": "Buława", "staff": "Kostur", "bow": "Łuk"}


## Nazwa rodzaju broni w wybranym języku (klucz weapon.<id>), zapasowo polska z WEAPON_TYPE_NAMES.
static func weapon_type_name(type_id: String) -> String:
	return QuizRpgI18n.t("weapon." + type_id, str(WEAPON_TYPE_NAMES.get(type_id, type_id)))


## HP przywracane celowi o maks. HP max_hp (stałe + procent).
func hp_restore_for(max_hp: int) -> int:
	return heal_amount + (ceili(max_hp * heal_percent) if heal_percent > 0.0 else 0)


## SP przywracane celowi o maks. SP max_sp (stałe + procent).
func sp_restore_for(max_sp: int) -> int:
	return sp_restore + (ceili(max_sp * sp_percent) if sp_percent > 0.0 else 0)


func get_effect_summary() -> String:
	var parts: Array[String] = []
	if heal_amount > 0:
		parts.append("+%d HP" % heal_amount)
	if heal_percent > 0.0:
		parts.append("+%d%% HP" % roundi(heal_percent * 100.0))
	if sp_restore > 0:
		parts.append("+%d SP" % sp_restore)
	if sp_percent > 0.0:
		parts.append("+%d%% SP" % roundi(sp_percent * 100.0))
	if tp_restore > 0:
		parts.append("+%d TP" % tp_restore)
	if cure_statuses.has("poison"):
		parts.append(QuizRpgI18n.t("item.effect.cures_poison", "leczy zatrucie"))
	return ", ".join(parts)


## Nazwa przedmiotu w wybranym języku (klucz "item.<plik>.name", zapasowo display_name).
func localized_name() -> String:
	var base := resource_path.get_file().get_basename()
	if base == "" and item_id != "":
		base = item_id
	if base != "":
		return QuizRpgI18n.t("item." + base + ".name", display_name)
	return display_name


## Opis przedmiotu w wybranym języku (klucz "item.<plik>.desc", zapasowo description).
func localized_description() -> String:
	var base := resource_path.get_file().get_basename()
	if base == "" and item_id != "":
		base = item_id
	if base != "":
		return QuizRpgI18n.t("item." + base + ".desc", description)
	return description
