extends Node

signal quiz_source_registered(module_id: String, source_path: String)
signal quiz_loaded(module_id: String, quiz_id: String)
signal question_answered(module_id: String, quiz_id: String, correct: bool, question_data: Dictionary)
signal quiz_completed(module_id: String, quiz_id: String, score: int, total: int)
## Zmiana zestawów / wyboru aktywnych (edytor pytań, opcje) — po reload_all().
signal questions_changed

const GLOBAL_SOURCE_PATH := "res://_host/resources/quizzes"
const WORDS_PER_SEC := 0.35
const DIFF_STEP_SEC := 3.0
const TYPE_MULTIPLIER := {
	"true_false": 0.80,
	"multiple_choice": 1.00,
	"fill_text": 1.20,
	"fill_tiles": 1.40,
	"matching": 1.55,
}

var _sources: Dictionary = {}
var _quizzes: Dictionary = {}
var _answered_questions: Dictionary = {}
var _sessions: Dictionary = {}
var _selection: Dictionary = {}   # wybór aktywnych zestawów / pytań (QuestionBank.load_selection)


func _ready() -> void:
	# Automatycznie załaduj bazę quizów z głównego folderu do puli globalnej i domyślnej
	register_sources("global", [GLOBAL_SOURCE_PATH], true)
	register_sources("", [GLOBAL_SOURCE_PATH], true)


func register_source(module_id: String, source_path: String, reload_now: bool = true) -> void:
	register_sources(module_id, [source_path], reload_now)


func register_sources(module_id: String, source_paths: Array, reload_now: bool = true) -> void:
	var cleaned_sources: Array[String] = []
	# Zestawy własne (import, nowe, edycje wbudowanych) zawsze na końcu — ten sam id przesłania wbudowany.
	source_paths = source_paths + [QuestionBank.USER_DIR]
	for source_path_variant in source_paths:
		var source_path := str(source_path_variant).trim_suffix("/")
		if source_path == "":
			continue
		if not cleaned_sources.has(source_path):
			cleaned_sources.append(source_path)
	_sources[module_id] = cleaned_sources
	if not _quizzes.has(module_id):
		_quizzes[module_id] = {}
	if reload_now:
		reload_module(module_id)
	for source_path in cleaned_sources:
		quiz_source_registered.emit(module_id, source_path)


func register_module(manifest: Dictionary) -> void:
	var module_id := str(manifest.get("id", ""))
	var root_path := str(manifest.get("root_path", ""))
	var quiz_path := str(manifest.get("quiz_path", "resources/quizzes"))
	if module_id == "" or root_path == "":
		return
	register_sources(module_id, [
		GLOBAL_SOURCE_PATH,
		_join_path(root_path, quiz_path),
	])


func reload_module(module_id: String) -> void:
	if not _sources.has(module_id):
		return

	_quizzes[module_id] = {}
	for source_path_variant in _sources[module_id]:
		var source_path := str(source_path_variant)
		var dir := DirAccess.open(source_path)
		if dir == null:
			continue

		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var quiz_id := file_name.get_basename()
				_load_quiz_file(module_id, quiz_id, "%s/%s" % [source_path, file_name])
			file_name = dir.get_next()
		dir.list_dir_end()


func _get_module_quizzes(module_id: String) -> Dictionary:
	var quizzes: Dictionary = _quizzes.get(module_id, {})
	if not quizzes.is_empty():
		return quizzes
	for fallback_mod in ["quiz_rpg", "global", ""]:
		var fallback_quizzes: Dictionary = _quizzes.get(fallback_mod, {})
		if not fallback_quizzes.is_empty():
			return fallback_quizzes
	return {}


func _resolve_quiz_id(module_id: String, quiz_id: String) -> String:
	var clean_id := quiz_id.strip_edges()
	var module_quizzes := _get_module_quizzes(module_id)

	if clean_id != "" and clean_id != "default" and module_quizzes.has(clean_id):
		return clean_id

	if clean_id != "" and clean_id != "default":
		for fallback_mod in ["", "global", "quiz_rpg"]:
			if _quizzes.get(fallback_mod, {}).has(clean_id):
				return clean_id

	# Fallback dla "default" lub nieznalezionego quiz_id
	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and "active_quiz_override" in cheat_service:
		var override_id: String = str(cheat_service.active_quiz_override).strip_edges()
		if override_id != "" and module_quizzes.has(override_id):
			return override_id

	if module_quizzes.has("inf_podst"):
		return "inf_podst"
	for fallback_mod in ["", "global", "quiz_rpg"]:
		if _quizzes.get(fallback_mod, {}).has("inf_podst"):
			return "inf_podst"

	if not module_quizzes.is_empty():
		return str(module_quizzes.keys()[0])
	for fallback_mod in ["", "global", "quiz_rpg"]:
		var fallback_quizzes: Dictionary = _quizzes.get(fallback_mod, {})
		if not fallback_quizzes.is_empty():
			return str(fallback_quizzes.keys()[0])

	return clean_id


func get_quiz_ids(module_id: String = "") -> Array:
	if module_id != "":
		var quizzes := _get_module_quizzes(module_id)
		return quizzes.keys()

	var result: Array = []
	for registered_module_id in _quizzes:
		for quiz_id in _quizzes[registered_module_id]:
			var entry: String = ("%s:%s" % [registered_module_id, quiz_id]) if registered_module_id != "" else str(quiz_id)
			if not result.has(entry):
				result.append(entry)
	return result


func get_questions(
	module_id: String,
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = []
) -> Array:
	var pool := _active_pool(module_id, quiz_id.strip_edges())
	if pool.is_empty():
		var effective_quiz_id := _resolve_quiz_id(module_id, quiz_id)
		var module_quizzes := _get_module_quizzes(module_id)
		if not module_quizzes.has(effective_quiz_id):
			push_warning("QuizService: quiz '%s' (resolved '%s') not found for module '%s'" % [quiz_id, effective_quiz_id, module_id])
			return []
		pool = module_quizzes[effective_quiz_id]

	var filtered: Array = []
	for question in pool:
		var diff: int = question.get("difficulty", 1)
		var qtype: String = question.get("type", "multiple_choice")
		var diff_ok := diff >= difficulty_range.x and diff <= difficulty_range.y
		var type_ok := allowed_types.is_empty() or (qtype in allowed_types)
		if diff_ok and type_ok:
			filtered.append(question)

	# Jeśli filtr trudności/typów nie znalazł pytań, złagodź filtr:
	if filtered.is_empty() and not pool.is_empty():
		for question in pool:
			var qtype: String = question.get("type", "multiple_choice")
			if allowed_types.is_empty() or (qtype in allowed_types):
				filtered.append(question)
		if filtered.is_empty():
			filtered = pool.duplicate()

	filtered.shuffle()
	if filtered.size() > count:
		filtered.resize(count)
	return filtered


func start_quiz(
	module_id: String,
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = [],
	session_id: String = "default"
) -> Dictionary:
	var effective_quiz_id := _resolve_quiz_id(module_id, quiz_id)
	# Losowanie z puli aktywnych (pierwotny quiz_id — nieznany zestaw = wszystkie aktywne).
	var questions := get_questions(module_id, quiz_id, difficulty_range, count, allowed_types)
	var key := _session_key(module_id, session_id)
	_sessions[key] = {
		"module_id": module_id,
		"quiz_id": effective_quiz_id,
		"questions": questions,
		"index": 0,
		"score": 0,
	}

	if questions.is_empty():
		return {}

	quiz_loaded.emit(module_id, effective_quiz_id)
	return questions[0]


func start_custom_questions(
	module_id: String,
	questions: Array,
	quiz_id: String = "custom",
	session_id: String = "default"
) -> Dictionary:
	var key := _session_key(module_id, session_id)
	_sessions[key] = {
		"module_id": module_id,
		"quiz_id": quiz_id,
		"questions": questions.duplicate(true),
		"index": 0,
		"score": 0,
	}

	if questions.is_empty():
		return {}

	quiz_loaded.emit(module_id, quiz_id)
	return questions[0]


func answer_current(module_id: String, player_answer: Dictionary, session_id: String = "default") -> Dictionary:
	var key := _session_key(module_id, session_id)
	if not _sessions.has(key):
		return {}

	var session: Dictionary = _sessions[key]
	var questions: Array = session["questions"]
	var index: int = session["index"]
	if index >= questions.size():
		return {}

	var question: Dictionary = questions[index]
	var correct := _check_answer(question, player_answer)
	if correct:
		session["score"] += 1

	var quiz_id: String = session["quiz_id"]
	_record_answer(module_id, question, correct)
	question_answered.emit(module_id, quiz_id, correct, question)

	session["index"] = index + 1
	var finished: bool = int(session["index"]) >= questions.size()
	if finished:
		quiz_completed.emit(module_id, quiz_id, session["score"], questions.size())

	return {
		"correct": correct,
		"question_type": question.get("type", "multiple_choice"),
		"correct_index": question.get("correct_index", 0),
		"correct_answer": question.get("correct_answer", null),
		"answer": question.get("answer", ""),
		"gaps": question.get("gaps", []),
		"pairs": question.get("pairs", []),
		"explanation": question.get("explanation", ""),
		"quiz_finished": finished,
		"score": session["score"],
		"total": questions.size(),
	}


func get_current_question(module_id: String, session_id: String = "default") -> Dictionary:
	var session: Dictionary = _sessions.get(_session_key(module_id, session_id), {})
	var questions: Array = session.get("questions", [])
	var index: int = session.get("index", 0)
	if index < questions.size():
		return questions[index]
	return {}


func get_question_display_text(question: Dictionary) -> String:
	match str(question.get("type", "multiple_choice")):
		"true_false":
			return str(question.get("statement", ""))
		"fill_text":
			return str(question.get("prompt", ""))
		"fill_tiles":
			return str(question.get("text_with_gaps", ""))
		_:
			return str(question.get("question", question.get("prompt", "")))


func get_question_hint(question: Dictionary) -> String:
	match str(question.get("type", "multiple_choice")):
		"multiple_choice":
			return "W/S/A/D lub strzalki, Enter/Z/Spacja zatwierdza"
		"true_false":
			return "W/S/A/D lub strzalki, Enter/Z/Spacja zatwierdza"
		"fill_text":
			return "Wpisz odpowiedz i Enter"
		"fill_tiles":
			return "Klikaj kafle, Tab zmienia luke, Enter zatwierdza"
		"matching":
			return "Lewa -> prawa, Enter zatwierdza"
		_:
			return ""


func get_question_time_limit(question: Dictionary, base_time: float = 16.0, base_difficulty: int = 1) -> float:
	var word_count := 0
	for field in [
		question.get("question", ""),
		question.get("statement", ""),
		question.get("prompt", ""),
		question.get("text_with_gaps", ""),
	]:
		if str(field) != "":
			word_count += str(field).split(" ", false).size()
	for answer in question.get("answers", []):
		word_count += str(answer).split(" ", false).size()
	for item in question.get("left_items", []):
		word_count += str(item).split(" ", false).size()
	for item in question.get("right_items", []):
		word_count += str(item).split(" ", false).size()
	var word_bonus := float(word_count) * WORDS_PER_SEC
	var qtype := str(question.get("type", "multiple_choice"))
	var type_mult := float(TYPE_MULTIPLIER.get(qtype, 1.0))
	var diff_offset := float(int(question.get("difficulty", base_difficulty)) - base_difficulty) * DIFF_STEP_SEC
	return clampf((base_time + word_bonus) * type_mult + diff_offset, 5.0, 120.0)


func get_timeout_answer(question: Dictionary) -> Dictionary:
	match str(question.get("type", "multiple_choice")):
		"multiple_choice":
			return {"index": -1}
		"true_false":
			return {"value": null}
		"fill_text":
			return {"text": ""}
		"fill_tiles":
			return {"placements": {}}
		"matching":
			return {"pairs": []}
		_:
			return {}


func get_correct_answer_text(question: Dictionary) -> String:
	match str(question.get("type", "multiple_choice")):
		"fill_text":
			var values: Array[String] = [str(question.get("answer", ""))]
			for alt in question.get("accepted_alternatives", []):
				values.append(str(alt))
			return "Poprawne: %s" % ", ".join(values)
		"fill_tiles":
			var values: Array[String] = []
			for gap in question.get("gaps", []):
				values.append(str(gap.get("correct", "")))
			return "Poprawna kolejnosc: %s" % ", ".join(values)
		"matching":
			var left_items: Array = question.get("left_items", [])
			var right_items: Array = question.get("right_items", [])
			var lines: Array[String] = []
			for pair in question.get("pairs", []):
				var left_index := int(pair.get("left_index", -1))
				var right_index := int(pair.get("right_index", -1))
				if left_index >= 0 and left_index < left_items.size() and right_index >= 0 and right_index < right_items.size():
					lines.append("%s -> %s" % [str(left_items[left_index]), str(right_items[right_index])])
			return "Poprawne:\n%s" % "\n".join(lines)
		_:
			return ""


func get_save_data(module_id: String = "") -> Dictionary:
	if module_id != "":
		return {
			"answered_questions": _answered_questions.get(module_id, {}).duplicate(true),
		}
	return {
		"answered_questions": _answered_questions.duplicate(true),
	}


func get_accuracy_for_category(module_id: String, category: String) -> float:
	var module_quizzes: Dictionary = _quizzes.get(module_id, {})
	var module_answers: Dictionary = _answered_questions.get(module_id, {})
	var correct_count := 0
	var total_count := 0
	for quiz_id in module_quizzes:
		for question in module_quizzes[quiz_id]:
			if question.get("category", "") == category:
				var question_id := str(question.get("id", ""))
				if module_answers.has(question_id):
					correct_count += int(module_answers[question_id]["correct"])
					total_count += int(module_answers[question_id]["correct"]) + int(module_answers[question_id]["wrong"])
	if total_count == 0:
		return 0.5
	return float(correct_count) / float(total_count)


func get_overall_accuracy(module_id: String) -> float:
	var module_answers: Dictionary = _answered_questions.get(module_id, {})
	var correct_count := 0
	var total_count := 0
	for question_id in module_answers:
		correct_count += int(module_answers[question_id]["correct"])
		total_count += int(module_answers[question_id]["correct"]) + int(module_answers[question_id]["wrong"])
	if total_count == 0:
		return 0.5
	return float(correct_count) / float(total_count)


func load_save_data(module_id: String, data: Dictionary) -> void:
	_answered_questions[module_id] = data.get("answered_questions", {})


func reset_module(module_id: String) -> void:
	_answered_questions.erase(module_id)
	for key in _sessions.keys():
		if key.begins_with("%s/" % module_id):
			_sessions.erase(key)


func _load_quiz_file(module_id: String, quiz_id: String, path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("QuizService: cannot read %s" % path)
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning("QuizService: invalid JSON %s" % path)
		return

	var raw_questions: Array = []
	if json.data is Dictionary and json.data.has("questions"):
		raw_questions = json.data["questions"]
	elif json.data is Array:
		raw_questions = json.data
	else:
		push_warning("QuizService: unsupported quiz format in %s" % path)
		return

	var normalized := _normalize_questions(raw_questions, path)
	for q in normalized:
		q["set_id"] = quiz_id
	_quizzes[module_id][quiz_id] = normalized


## Po zmianach w zestawach / wyborze (edytor pytań, opcje): wczytanie od nowa wszystkich modułów.
func reload_all() -> void:
	_selection = QuestionBank.load_selection()
	for module_id in _sources:
		reload_module(module_id)
	questions_changed.emit()


## Pytania do losowania: zestaw `quiz_id`, gdy istnieje i jest aktywny (jego aktywne pytania), inaczej
## aktywne pytania wszystkich aktywnych zestawów (wybór: QuestionBank, opcje / edytor pytań).
## Pusto, gdy nic nie jest aktywne — wtedy get_questions bierze dawny zestaw quiz_id bez filtra.
func _active_pool(module_id: String, quiz_id: String) -> Array:
	if _selection.is_empty():
		_selection = QuestionBank.load_selection()
	var quizzes := _get_module_quizzes(module_id)
	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and "active_quiz_override" in cheat_service:
		var override_id := str(cheat_service.active_quiz_override).strip_edges()
		if override_id != "" and quizzes.has(override_id):
			return quizzes[override_id]  # menu deweloperskie: wymuszony zestaw, bez filtra
	var ids: Array = []
	if quizzes.has(quiz_id) and QuestionBank.is_set_enabled(quiz_id, _selection):
		ids = [quiz_id]
	else:
		for id in quizzes:
			if QuestionBank.is_set_enabled(str(id), _selection):
				ids.append(id)
	var pool: Array = []
	for id in ids:
		for q in quizzes[id]:
			if QuestionBank.is_question_enabled(str(id), str(q.get("id", "")), _selection):
				pool.append(q)
	return pool


func _check_answer(question: Dictionary, player_answer: Dictionary) -> bool:
	var qtype: String = question.get("type", "multiple_choice")
	match qtype:
		"multiple_choice":
			return player_answer.get("index", -1) == question.get("correct_index", -1)
		"true_false":
			return player_answer.get("value", null) == question.get("correct_answer", null)
		"fill_text":
			return _check_fill_text(question, player_answer)
		"fill_tiles":
			return _check_fill_tiles(question, player_answer)
		"matching":
			return _check_matching(question, player_answer)
		_:
			push_warning("QuizService: unknown question type '%s'" % qtype)
			return false


func _check_fill_text(question: Dictionary, player_answer: Dictionary) -> bool:
	var given := str(player_answer.get("text", "")).strip_edges()
	var expected := str(question.get("answer", "")).strip_edges()
	var alternatives: Array = question.get("accepted_alternatives", [])
	if not question.get("case_sensitive", false):
		given = given.to_lower()
		expected = expected.to_lower()
		alternatives = alternatives.map(func(value): return str(value).strip_edges().to_lower())
	return given == expected or given in alternatives


func _check_fill_tiles(question: Dictionary, player_answer: Dictionary) -> bool:
	var placements: Dictionary = player_answer.get("placements", {})
	for gap in question.get("gaps", []):
		var index := str(int(gap.get("index", -1)))
		var player_value := str(placements.get(index, "")).strip_edges().to_lower()
		var correct_value := str(gap.get("correct", "")).strip_edges().to_lower()
		if player_value != correct_value:
			return false
	return true


func _check_matching(question: Dictionary, player_answer: Dictionary) -> bool:
	var player_pairs: Array = player_answer.get("pairs", [])
	var correct_pairs: Array = question.get("pairs", [])
	if player_pairs.size() != correct_pairs.size():
		return false
	for correct_pair in correct_pairs:
		var found := false
		for player_pair in player_pairs:
			if player_pair.get("left_index", -1) == correct_pair.get("left_index", -1) \
			and player_pair.get("right_index", -1) == correct_pair.get("right_index", -1):
				found = true
				break
		if not found:
			return false
	return true


func _record_answer(module_id: String, question: Dictionary, correct: bool) -> void:
	if not _answered_questions.has(module_id):
		_answered_questions[module_id] = {}
	var question_id := str(question.get("id", "unknown"))
	if not _answered_questions[module_id].has(question_id):
		_answered_questions[module_id][question_id] = { "correct": 0, "wrong": 0 }
	if correct:
		_answered_questions[module_id][question_id]["correct"] += 1
	else:
		_answered_questions[module_id][question_id]["wrong"] += 1


func _session_key(module_id: String, session_id: String) -> String:
	return "%s/%s" % [module_id, session_id]


func _join_path(root_path: String, relative_path: String) -> String:
	if relative_path.begins_with("res://") or relative_path.begins_with("user://"):
		return relative_path
	return "%s/%s" % [root_path.trim_suffix("/"), relative_path.trim_prefix("/")]


func _normalize_questions(raw_questions: Array, path: String) -> Array:
	var normalized: Array = []
	for raw_question in raw_questions:
		if not (raw_question is Dictionary):
			push_warning("QuizService: skipping non-dictionary question in %s" % path)
			continue
		var question := (raw_question as Dictionary).duplicate(true)
		var qtype := str(question.get("type", "multiple_choice"))
		match qtype:
			"multiple_choice":
				if not question.has("question") or not question.has("answers") or not question.has("correct_index"):
					push_warning("QuizService: invalid multiple_choice question in %s" % path)
					continue
			"true_false":
				if not question.has("statement") or not question.has("correct_answer"):
					push_warning("QuizService: invalid true_false question in %s" % path)
					continue
				question["question"] = question.get("question", question["statement"])
				question["answers"] = question.get("answers", ["Prawda", "Falsz"])
				question["correct_index"] = 0 if bool(question["correct_answer"]) else 1
			"fill_text":
				if not question.has("prompt") or not question.has("answer"):
					push_warning("QuizService: invalid fill_text question in %s" % path)
					continue
				question["question"] = question.get("question", question["prompt"])
			"fill_tiles":
				if not question.has("text_with_gaps") or not question.has("gaps") or not question.has("tiles"):
					push_warning("QuizService: invalid fill_tiles question in %s" % path)
					continue
				question["question"] = question.get("question", question["text_with_gaps"])
			"matching":
				if not question.has("left_items") or not question.has("right_items") or not question.has("pairs"):
					push_warning("QuizService: invalid matching question in %s" % path)
					continue
				question["question"] = question.get("question", "Dopasuj elementy.")
			_:
				push_warning("QuizService: unknown question type '%s' in %s" % [qtype, path])
				continue
		normalized.append(question)
	return normalized
