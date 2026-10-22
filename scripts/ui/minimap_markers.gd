extends Control

## Znaczniki na minimapie (dziecko TextureRect mapy w scenes/ui/minimap.tscn, rozciągnięte na całą mapę): kwadraty
## w kratkach z listy minimapy (Minimap.markers: [kratka, kolor]), tylko na odkrytych kratkach. Rozmiar to kratka mapy
## w bieżącym powiększeniu × cell_factor, nie mniej niż min_size px; ciemny obrys, żeby odcinał się od podłogi.

@export var min_size := 7.0
@export var cell_factor := 1.5
@export var outline := Color(0.05, 0.04, 0.03, 0.9)

var minimap: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var data: QuizRpgMinimapData = minimap.get("data") if minimap != null else null
	if data == null or data.width == 0:
		return
	var cell := size / Vector2(data.width, data.height)
	var s := maxf(maxf(cell.x, cell.y) * cell_factor, min_size)
	for m: Array in minimap.get("markers"):
		var p: Vector2i = m[0]
		if not data.is_revealed(p):
			continue
		var center := (Vector2(p - data.origin) + Vector2(0.5, 0.5)) * cell
		var r := Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s))
		draw_rect(r.grow(1.0), outline)
		draw_rect(r, m[1])
