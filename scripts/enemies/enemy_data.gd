extends Resource
class_name QuizRpgEnemyData

@export_group("Identity")
@export var enemy_name: String = "Przeciwnik"
@export var quiz_id: String = "default"
@export var quiz_category: String = "ogolne"
@export var is_boss: bool = false

@export_group("Combat")
@export var question_count: int = 3
@export var max_hp: int = 50
@export var damage_on_wrong: int = 15
@export var xp_reward: int = 50
@export_range(1, 5, 1) var encounter_tier: int = 2
@export var min_encounter_size: int = 1
@export var max_encounter_size: int = 3

@export_group("Movement")
@export var patrol_speed: float = 80.0
@export var detection_radius: float = 150.0

@export_group("Visual")
@export var body_color: Color = Color(0.9, 0.2, 0.2)
@export var shape_type: int = 0
