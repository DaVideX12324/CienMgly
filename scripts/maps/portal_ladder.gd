@tool
extends Node2D

## Wejście / wyjście poziomu jako drabina na licu ściany ze snopem światła z włazu nad nią (portal_style "ladder").
## Węzeł stoi na środku kratki przejścia (podłoga pod ścianą); drabina sięga `height_cells` kratek lica w górę (3H / 4H),
## stożek światła od góry lica rozszerza się na podłogę. Wygląd (tekstury, kolor, przezroczystość) — w scenie.

const CELL := 16

@export_range(1, 8, 1) var height_cells := 3:
	set(v):
		height_cells = v
		_layout()

@onready var _ladder: Sprite2D = $Ladder
@onready var _light: Sprite2D = $Light


func _ready() -> void:
	_layout()


func _layout() -> void:
	if not is_node_ready():
		return
	# drabina: od górnej krawędzi lica do 4 px w głąb kratki przejścia (powtarzany kafel 16 × 32)
	var h := height_cells * CELL + CELL / 2 - 4
	_ladder.region_rect = Rect2(_ladder.region_rect.position, Vector2(_ladder.region_rect.size.x, h))
	_ladder.position = Vector2(-_ladder.region_rect.size.x * 0.5, -CELL / 2 - height_cells * CELL)
	# światło: od góry lica do kratki pod przejściem
	var tex_h := _light.region_rect.size.y
	var want := float((height_cells + 2) * CELL)
	_light.scale = Vector2(_light.scale.x, want / tex_h)
	_light.position = Vector2(0.0, -CELL / 2 - height_cells * CELL + want * 0.5)
