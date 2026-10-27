extends Control

## Animacja wejścia i wyjścia z walki (scena combat_intro.tscn): zrzut ekranu zamyka się w czerń, potem czerń
## płynnie znika i odsłania to, co pod spodem (wejście: ekran walki; wyjście: świat). Styl wybiera gracz
## (QuizTheme.combat_intro_style): „swirl” — wir z pikselizacją i źrenicą, „slices” — paski z glitchem.
## Działa przy spauzowanym drzewie (PROCESS_MODE_ALWAYS), blokuje wejście na czas trwania.

signal finished
## Obraz jest już cały czarny — tu wolno podmienić to, co pod spodem (wyjście z walki: usunąć ekran walki, odpauzować).
signal covered

const SWIRL_SHADER := preload("../../resources/shaders/combat_intro_swirl.gdshader")
## Czas zamykania w czerń dla każdego stylu.
const CLOSE_SECONDS := {"swirl": 0.95, "slices": 0.65}

@export var reveal_seconds := 0.55

@onready var _swirl: ColorRect = $Swirl


## snapshot — obraz widoku z chwili tuż przed walką.
func play(snapshot: Image, style: String = QuizTheme.INTRO_SWIRL) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if style == QuizTheme.INTRO_SWIRL:
		var swirl_mat := ShaderMaterial.new()
		swirl_mat.shader = SWIRL_SHADER
		_swirl.material = swirl_mat
	var mat := _swirl.material as ShaderMaterial
	mat.set_shader_parameter(&"snap", ImageTexture.create_from_image(snapshot))
	mat.set_shader_parameter(&"progress", 0.0)
	var close_tween := create_tween()
	close_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"progress", v), 0.0, 1.0, float(CLOSE_SECONDS.get(style, 0.8))) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close_tween.finished
	covered.emit()
	# Ciężka robota po `covered` (budowa ekranu walki, zwalnianie walki) ma się skończyć przy pełnej czerni —
	# inaczej skok delty zjada początek odsłaniania i wygląda jak lag/nagłe pojawienie się obrazu.
	await get_tree().process_frame
	await get_tree().process_frame
	var reveal_tween := create_tween()
	reveal_tween.tween_property(self, "modulate:a", 0.0, reveal_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal_tween.finished
	finished.emit()
	queue_free()
