@tool
class_name QuizRpgLampPost
extends StaticBody2D

## Słup z ramieniem (Pixel Crawler) o regulowanej wysokości: między podstawą a górą powielany jest 1 px pnia (wiersze pnia
## w arkuszu są identyczne, więc bez szwu). Góra (węzeł Top) jedzie w górę razem z tym, co jest do niej przypięte (latarnia).

## Dodatkowa wysokość pnia w pikselach (0 = oryginalne 46 px; ok. 17 = wysokość lampy Desert Town).
@export_range(0, 64) var pole_extra: int = 0:
	set(value):
		pole_extra = value
		if is_node_ready():
			_apply()

## Wysokość podstawy (dolny fragment sprite'a) — nad nią zaczyna się powielany pień.
const BASE_HEIGHT := 28


func _ready() -> void:
	_apply()


func _apply() -> void:
	($Top as Node2D).position.y = -pole_extra
	var ext := $PoleExtension as Sprite2D
	ext.visible = pole_extra > 0
	ext.scale.y = maxi(pole_extra, 1)
	ext.position.y = -BASE_HEIGHT - pole_extra
