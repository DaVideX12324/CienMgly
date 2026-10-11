extends Control

## Animacja wejścia do walki (scena combat_intro.tscn, shader combat_intro.gdshader): zrzut świata sprzed walki wiruje,
## pikseluje się i zamyka w czerń (zwarcie), potem znika i odsłania ekran walki. Działa przy spauzowanym drzewie
## (PROCESS_MODE_ALWAYS), blokuje wejście na czas trwania.

signal finished

@export var close_seconds := 0.55
@export var reveal_seconds := 0.3

@onready var _swirl: ColorRect = $Swirl


## snapshot — obraz widoku z chwili tuż przed walką.
func play(snapshot: Image) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var mat := _swirl.material as ShaderMaterial
	mat.set_shader_parameter(&"snap", ImageTexture.create_from_image(snapshot))
	mat.set_shader_parameter(&"progress", 0.0)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"progress", v), 0.0, 1.0, close_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, reveal_seconds)
	await tween.finished
	finished.emit()
	queue_free()
