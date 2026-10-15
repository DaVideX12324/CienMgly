class_name UiLayerScale
extends Node
## Skala UI z opcji (UIScaleService: auto z wysokości okna albo wybór gracza) dla całej warstwy UI modułu:
## CanvasLayer skalowany mnożnikiem, a jego bezpośrednie dzieci-Control układane w „logicznym” ekranie
## (rozmiar okna / mnożnik) wg kotwic ze sceny. Sceny są projektowane pod 1080p przy mnożniku 1 — czcionki, ramki,
## marginesy i potwory na polu walki skalują się razem (np. 1280×720: ×0,75, 2560×1440: ×1,5). Świat gry bez zmian.
##
## Użycie: UiLayerScale.attach(warstwa) w _ready warstwy (albo po jej utworzeniu w kodzie). Skrypty UI na takiej
## warstwie biorą rozmiar ekranu z UiLayerScale.screen_size(węzeł), nie z get_viewport_rect().

const NODE_NAME := &"UiLayerScale"
const META_ANCHORS := &"_ui_layer_anchors"


static func attach(layer: CanvasLayer) -> void:
	if layer.has_meta(NODE_NAME):
		return
	var helper := UiLayerScale.new()
	helper.name = NODE_NAME
	layer.set_meta(NODE_NAME, helper)
	# Wołane też z _ready dziecka warstwy — wtedy warstwa jeszcze dodaje dzieci, więc od razu tylko skala
	# i układ, a węzeł pomocnika (sygnały) dochodzi po klatce.
	if layer.is_node_ready():
		layer.add_child(helper)
	else:
		layer.add_child.call_deferred(helper)
		apply_now(layer)


## Jednorazowe ułożenie warstwy (bez śledzenia zmian okna / skali) — przed dodaniem pomocnika.
static func apply_now(layer: CanvasLayer) -> void:
	if layer.is_inside_tree():
		_layout(layer)


## Mnożnik skali UI (1.0 bez UIScaleService, np. w narzędziach).
static func factor(node: Node) -> float:
	var service: Node = node.get_node_or_null(^"/root/UIScaleService") if node.is_inside_tree() else null
	return maxf(float(service.get("scale_factor")), 0.1) if service else 1.0


## Rozmiar ekranu w jednostkach skalowanej warstwy UI (okno / mnożnik).
static func screen_size(node: CanvasItem) -> Vector2:
	return node.get_viewport_rect().size / factor(node)


func _ready() -> void:
	var layer := get_parent() as CanvasLayer
	if layer == null:
		push_warning("UiLayerScale: rodzic nie jest CanvasLayer")
		return
	get_viewport().size_changed.connect(_apply)
	var service: Node = get_node_or_null(^"/root/UIScaleService")
	if service and service.has_signal("scale_changed"):
		service.connect("scale_changed", func(_f: float) -> void: _apply())
	# Okna dodawane później z kodu (np. dymki łupów) — po ustawieniu ich kotwic.
	layer.child_entered_tree.connect(func(_n: Node) -> void: _apply.call_deferred())
	_apply()


func _apply() -> void:
	var layer := get_parent() as CanvasLayer
	if layer != null and is_inside_tree():
		_layout(layer)


static func _layout(layer: CanvasLayer) -> void:
	var s := factor(layer)
	layer.scale = Vector2(s, s)
	var screen := layer.get_viewport().get_visible_rect().size / s
	for child in layer.get_children():
		var ctl := child as Control
		if ctl == null:
			continue
		if not ctl.has_meta(META_ANCHORS):
			ctl.set_meta(META_ANCHORS, PackedFloat32Array([ctl.anchor_left, ctl.anchor_top, ctl.anchor_right,
					ctl.anchor_bottom, ctl.offset_left, ctl.offset_top, ctl.offset_right, ctl.offset_bottom]))
		var a: PackedFloat32Array = ctl.get_meta(META_ANCHORS)
		# Kotwice liczą się od okna (nie od warstwy) — dlatego kotwice 0 i pozycja wprost w ekranie logicznym.
		ctl.anchor_left = 0.0
		ctl.anchor_top = 0.0
		ctl.anchor_right = 0.0
		ctl.anchor_bottom = 0.0
		ctl.offset_left = a[0] * screen.x + a[4]
		ctl.offset_top = a[1] * screen.y + a[5]
		ctl.offset_right = a[2] * screen.x + a[6]
		ctl.offset_bottom = a[3] * screen.y + a[7]
