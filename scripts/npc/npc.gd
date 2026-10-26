@tool
class_name QuizRpgNpc
extends StaticBody2D

## NPC miasta (scena-szablon scenes/npc/npc.tscn i dziedziczące: sklepikarka, karczmarka, nauczyciel, mieszkaniec):
## klawisz interakcji -> powitanie, potem menu usług (QuizRpgNpcService: sklep, odpoczynek, nauka umiejętności,
## rozmowa; wspomnienia `auto_once` odtwarzają się raz przed menu) i „Do widzenia”; po usłudze menu wraca. NPC z jedną rozmową i bez innych usług mówi ją od razu.
## Przez całą rozmowę gra jest w stanie CUTSCENE (wrogowie i gracz stoją). Wygląd: sprite_frames (animacja
## „idle”), widoczny też w edytorze. Niezależny od układu mapy — wstawia się go w dowolną scenę.

const DialogBox = preload("../ui/dialog_box.gd")

@export var npc_name: String = "Mieszkaniec"
## Klucz tłumaczenia imienia (pusty = npc_name).
@export var npc_name_key: String = ""
@export var sprite_frames: SpriteFrames:
	set(v):
		sprite_frames = v
		if is_node_ready():
			_apply_look()
## Przesunięcie sprite'a: stopy postaci ok. 2 px pod punktem NPC (klatki z mieszkańcami: -14; royal / elf crew: -30).
@export var sprite_offset: Vector2 = Vector2(0, -14):
	set(v):
		sprite_offset = v
		if is_node_ready():
			_apply_look()
@export var face_left: bool = false:
	set(v):
		face_left = v
		if is_node_ready():
			_apply_look()
## Powitanie przed menu usług (puste = od razu menu).
@export var greeting: PackedStringArray = []
@export var greeting_key: String = ""
@export var services: Array[QuizRpgNpcService] = []
## Linie na pożegnanie (puste = bez).
@export var farewell: PackedStringArray = []
@export var farewell_key: String = ""
## Stanowisko pracy rzemieślnika (QuizRpgStation w mieście): po usłudze z efektem (np. ulepszeniu) NPC idzie do niego,
## stanowisko gra animację „work” przez work_seconds, NPC wraca na miejsce. Puste = bez wędrówki.
@export var work_station: QuizRpgStation
@export var work_seconds: float = 3.0
@export var walk_speed: float = 60.0

var _busy := false


func _ready() -> void:
	_apply_look()


func _apply_look() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.sprite_frames = sprite_frames
	sprite.flip_h = face_left
	sprite.offset = sprite_offset
	if sprite_frames != null and sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")


## Idzie do stanowiska, pracuje przy nim i wraca (korutyna); bez work_station nic nie robi.
func work_at_station() -> void:
	if work_station == null or not is_inside_tree():
		return
	var home := global_position
	await _walk_to(work_station.work_spot())
	work_station.start_work()
	await get_tree().create_timer(work_seconds).timeout
	work_station.stop_work()
	await _walk_to(home)
	_apply_look()
	await say(PackedStringArray([QuizRpgI18n.t("npc.work.done", "Gotowe.")]))


## Przejście po prostej (NPC bez animacji chodu: idle, zwrócony w stronę celu); na czas drogi bez kolizji.
func _walk_to(target: Vector2) -> void:
	var dist := global_position.distance_to(target)
	if dist < 1.0:
		return
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.flip_h = target.x < global_position.x
	var layer := collision_layer
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, dist / maxf(walk_speed, 1.0))
	await tween.finished
	collision_layer = layer


func display_name() -> String:
	return QuizRpgI18n.t(npc_name_key, npc_name) if npc_name_key != "" else npc_name


func can_interact() -> bool:
	return not _busy


func interaction_prompt_text() -> String:
	return QuizRpgI18n.t("prompt.talk", "Porozmawiaj")


func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -34)


func interact(_player: Node2D) -> void:
	if _busy:
		return
	_busy = true
	_set_state(true)
	await _session()
	_set_state(false)
	_busy = false


func _session() -> void:
	for s in services:
		if s is QuizRpgNpcTalk and s.is_pending_recall(self):
			await s.run(self)
	var avail := available_services()
	var only_talk := avail.size() == 1 and avail[0] is QuizRpgNpcTalk
	if not greeting.is_empty():
		await say(QuizRpgNpcContext.lines(greeting, greeting_key))
	if only_talk:
		await avail[0].run(self)
	elif not avail.is_empty():
		while true:
			avail = available_services()
			var opts := PackedStringArray()
			for s in avail:
				opts.append(s.localized_label())
			opts.append(QuizRpgI18n.t("npc.bye", "Do widzenia"))
			var pick: int = await ask(QuizRpgI18n.t("npc.menu_question", "W czym mogę pomóc?"), opts)
			if pick < 0 or pick >= avail.size():
				break
			await avail[pick].run(self)
	if not farewell.is_empty():
		await say(QuizRpgNpcContext.lines(farewell, farewell_key))


func available_services() -> Array[QuizRpgNpcService]:
	var out: Array[QuizRpgNpcService] = []
	for s in services:
		if s != null and s.is_available(self):
			out.append(s)
	return out


## Linie w oknie rozmowy z imieniem NPC (korutyna).
func say(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	var box := DialogBox.open(self, display_name(), lines, false)
	await box.finished


## Pytanie z opcjami (korutyna) -> indeks wybranej opcji.
func ask(question: String, options: PackedStringArray) -> int:
	var box := DialogBox.ask(self, display_name(), question, options, false)
	return await box.chosen



func _set_state(talking: bool) -> void:
	var gm := QuizRpgNpcContext.singleton(self, "GameManager")
	if gm and gm.has_method("change_state"):
		gm.change_state(gm.GameState.CUTSCENE if talking else gm.GameState.EXPLORING)
