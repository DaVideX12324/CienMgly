class_name QuestionBank
extends RefCounted

## Zestawy pytań (wspólne dla modułów, ładuje je QuizService) i wybór aktywnych w grze.
##
## - Wbudowane: res://_host/resources/quizzes/<id>.json (tylko do odczytu po eksporcie gry).
## - Własne: user://quizzes/<id>.json — import, nowe zestawy i edycje wbudowanych (plik o tym samym id
##   przesłania wbudowany; „przywróć oryginał” = usunięcie pliku z user://).
## - Wybór aktywnych: user://quiz_selection.json — zestawy włączone / wyłączone i wyłączone pytania
##   (globalnie, dla wszystkich modułów i zapisów). Domyślnie aktywne: własne zestawy i DEFAULT_ACTIVE_SETS.
##
## Format zestawu: {"name", "description", "questions": [...]} (albo sama tablica pytań). Typy pytań:
## multiple_choice, true_false, fill_text, fill_tiles, matching — pola jak w resources/quizzes.

const BUILTIN_DIR := "res://_host/resources/quizzes"
const USER_DIR := "user://quizzes"
const SELECTION_PATH := "user://quiz_selection.json"
const DEFAULT_ACTIVE_SETS: Array[String] = ["inf_podst"]
const GAP_MARK := "___"

const TYPES: Array[String] = ["multiple_choice", "true_false", "fill_text", "fill_tiles", "matching"]
const TYPE_NAMES := {
	"multiple_choice": "Wybór odpowiedzi",
	"true_false": "Prawda / fałsz",
	"fill_text": "Wpisz odpowiedź",
	"fill_tiles": "Uzupełnij kafelkami",
	"matching": "Dopasuj pary",
}
const ID_PREFIX := {
	"multiple_choice": "mc",
	"true_false": "tf",
	"fill_text": "ftext",
	"fill_tiles": "ft",
	"matching": "match",
}


# --- Zestawy ---------------------------------------------------------------------------------------

## Wszystkie zestawy: [{id, name, description, questions, source: "builtin" | "edited" | "user"}],
## posortowane po nazwie.
static func list_sets() -> Array[Dictionary]:
	var by_id := {}
	for f in _json_files(BUILTIN_DIR):
		var data := _read_set(BUILTIN_DIR.path_join(f))
		if not data.is_empty():
			data["id"] = f.get_basename()
			data["source"] = "builtin"
			by_id[data["id"]] = data
	for f in _json_files(USER_DIR):
		var data := _read_set(USER_DIR.path_join(f))
		if data.is_empty():
			continue
		var id := f.get_basename()
		data["id"] = id
		data["source"] = "edited" if by_id.has(id) else "user"
		by_id[id] = data
	var out: Array[Dictionary] = []
	for id in by_id:
		out.append(by_id[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return out


static func get_set(id: String) -> Dictionary:
	for s in list_sets():
		if s["id"] == id:
			return s
	return {}


static func is_builtin(id: String) -> bool:
	return FileAccess.file_exists(BUILTIN_DIR.path_join(id + ".json"))


## Zapis zestawu do user:// (wbudowany -> wersja edytowana, przesłania oryginał).
static func save_set(id: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))
	var out := {
		"name": str(data.get("name", id)),
		"description": str(data.get("description", "")),
		"questions": data.get("questions", []),
	}
	var f := FileAccess.open(USER_DIR.path_join(id + ".json"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(out, "\t", false))
	f.close()
	return true


## Usuwa własny zestaw albo edycję wbudowanego (wraca oryginał). Wbudowanego oryginału nie da się usunąć.
static func delete_user_file(id: String) -> bool:
	var path := USER_DIR.path_join(id + ".json")
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


static func new_set_id(base: String) -> String:
	var slug := _slug(base)
	if slug == "":
		slug = "zestaw"
	var id := slug
	var n := 2
	while is_builtin(id) or FileAccess.file_exists(USER_DIR.path_join(id + ".json")):
		id = "%s_%d" % [slug, n]
		n += 1
	return id


# --- Import / eksport -------------------------------------------------------------------------------

## Import pliku JSON jako nowy zestaw: poprawne pytania zapisane, błędne pominięte z powodem.
## Wynik: {ok, id, name, imported, skipped: [{index, reason}], error}.
static func import_file(path: String) -> Dictionary:
	var result := {"ok": false, "id": "", "name": "", "imported": 0, "skipped": [], "error": ""}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		result["error"] = "Nie udało się odczytać pliku."
		return result
	var json := JSON.new()
	if json.parse(text) != OK:
		result["error"] = "Błędny JSON (linia %d): %s" % [json.get_error_line(), json.get_error_message()]
		return result
	var raw: Array = []
	var name := path.get_file().get_basename()
	var description := ""
	if json.data is Dictionary and (json.data as Dictionary).has("questions") and json.data["questions"] is Array:
		raw = json.data["questions"]
		name = str(json.data.get("name", name))
		description = str(json.data.get("description", ""))
	elif json.data is Array:
		raw = json.data
	else:
		result["error"] = "Nieobsługiwany format: oczekiwano {\"questions\": [...]} albo tablicy pytań."
		return result
	var questions: Array = []
	var used_ids := {}
	for i in range(raw.size()):
		var q: Variant = raw[i]
		if not (q is Dictionary):
			result["skipped"].append({"index": i + 1, "reason": "to nie jest obiekt pytania"})
			continue
		var question := (q as Dictionary).duplicate(true)
		if not question.has("type"):
			question["type"] = "multiple_choice"
		var err := validate_question(question)
		if err != "":
			result["skipped"].append({"index": i + 1, "reason": err})
			continue
		var qid := str(question.get("id", ""))
		if qid == "" or used_ids.has(qid):
			qid = _next_id(questions, str(question["type"]))
		question["id"] = qid
		used_ids[qid] = true
		questions.append(question)
	if questions.is_empty():
		result["error"] = "Brak poprawnych pytań w pliku."
		return result
	var id := new_set_id(name)
	if not save_set(id, {"name": name, "description": description, "questions": questions}):
		result["error"] = "Nie udało się zapisać zestawu."
		return result
	result["ok"] = true
	result["id"] = id
	result["name"] = name
	result["imported"] = questions.size()
	return result


static func export_set(id: String, path: String) -> bool:
	var s := get_set(id)
	if s.is_empty():
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"name": s["name"], "description": s.get("description", ""), "questions": s["questions"]}, "\t", false))
	f.close()
	return true


# --- Pytania ----------------------------------------------------------------------------------------

## "" gdy pytanie poprawne, inaczej powód (po polsku) — te same wymagania co QuizService + spójność
## (indeksy w zakresie, liczba luk, pary).
static func validate_question(q: Dictionary) -> String:
	var t := str(q.get("type", ""))
	if not TYPES.has(t):
		return "nieznany typ „%s”" % t
	var diff := int(q.get("difficulty", 1))
	if diff < 1 or diff > 5:
		return "trudność poza zakresem 1–5"
	match t:
		"multiple_choice":
			if str(q.get("question", "")).strip_edges() == "":
				return "brak treści pytania"
			var answers: Variant = q.get("answers", [])
			if not (answers is Array) or (answers as Array).size() < 2:
				return "potrzebne co najmniej 2 odpowiedzi"
			for a in answers:
				if str(a).strip_edges() == "":
					return "pusta odpowiedź"
			var ci := int(q.get("correct_index", -1))
			if ci < 0 or ci >= (answers as Array).size():
				return "nie wskazano poprawnej odpowiedzi"
		"true_false":
			if str(q.get("statement", "")).strip_edges() == "":
				return "brak twierdzenia"
			if not q.has("correct_answer"):
				return "brak poprawnej odpowiedzi (prawda / fałsz)"
		"fill_text":
			if str(q.get("prompt", "")).strip_edges() == "":
				return "brak treści pytania"
			if str(q.get("answer", "")).strip_edges() == "":
				return "brak odpowiedzi"
		"fill_tiles":
			var text := str(q.get("text_with_gaps", ""))
			var gap_count := text.count(GAP_MARK)
			if gap_count == 0:
				return "tekst bez luk (wstaw %s w miejscu luki)" % GAP_MARK
			var gaps: Variant = q.get("gaps", [])
			if not (gaps is Array) or (gaps as Array).size() != gap_count:
				return "liczba luk (%d) nie zgadza się z liczbą odpowiedzi" % gap_count
			var tiles: Variant = q.get("tiles", [])
			if not (tiles is Array):
				return "brak kafelków"
			for g in gaps:
				if not (g is Dictionary) or str(g.get("correct", "")).strip_edges() == "":
					return "pusta odpowiedź w luce"
				if not (tiles as Array).has(g["correct"]):
					return "kafelki nie zawierają odpowiedzi „%s”" % g["correct"]
		"matching":
			var left: Variant = q.get("left_items", [])
			var right: Variant = q.get("right_items", [])
			var pairs: Variant = q.get("pairs", [])
			if not (left is Array) or not (right is Array) or not (pairs is Array):
				return "brak elementów do dopasowania"
			if (left as Array).size() < 2:
				return "potrzebne co najmniej 2 pary"
			if (left as Array).size() != (right as Array).size() or (pairs as Array).size() != (left as Array).size():
				return "liczba elementów i par się nie zgadza"
			for p in pairs:
				if not (p is Dictionary):
					return "błędna para"
				var li := int(p.get("left_index", -1))
				var ri := int(p.get("right_index", -1))
				if li < 0 or li >= (left as Array).size() or ri < 0 or ri >= (right as Array).size():
					return "para wskazuje poza listę"
			for item in (left as Array) + (right as Array):
				if str(item).strip_edges() == "":
					return "pusty element pary"
	return ""


## Krótki opis pytania do listy (treść / twierdzenie / tekst z lukami).
static func question_text(q: Dictionary) -> String:
	for key in ["question", "statement", "prompt", "text_with_gaps"]:
		if q.has(key) and str(q[key]) != "":
			return str(q[key])
	if q.get("type", "") == "matching":
		return "Dopasuj: " + ", ".join(PackedStringArray((q.get("left_items", []) as Array).map(func(x): return str(x))))
	return ""


static func _next_id(questions: Array, type: String) -> String:
	var prefix: String = ID_PREFIX.get(type, "q")
	var used := {}
	for q in questions:
		used[str(q.get("id", ""))] = true
	var n := 1
	while used.has("%s_%03d" % [prefix, n]):
		n += 1
	return "%s_%03d" % [prefix, n]


static func next_question_id(questions: Array, type: String) -> String:
	return _next_id(questions, type)


# --- Wybór aktywnych ---------------------------------------------------------------------------------

static func load_selection() -> Dictionary:
	var sel := {"enabled_sets": [], "disabled_sets": [], "disabled_questions": {}}
	if FileAccess.file_exists(SELECTION_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SELECTION_PATH))
		if data is Dictionary:
			for k in sel:
				if (data as Dictionary).has(k):
					sel[k] = data[k]
	return sel


static func save_selection(sel: Dictionary) -> void:
	var f := FileAccess.open(SELECTION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(sel, "\t"))
		f.close()


static func is_set_enabled(id: String, sel: Dictionary = {}) -> bool:
	if sel.is_empty():
		sel = load_selection()
	if (sel["enabled_sets"] as Array).has(id):
		return true
	if (sel["disabled_sets"] as Array).has(id):
		return false
	return DEFAULT_ACTIVE_SETS.has(id) or not is_builtin(id)


static func set_set_enabled(id: String, enabled: bool) -> void:
	var sel := load_selection()
	(sel["enabled_sets"] as Array).erase(id)
	(sel["disabled_sets"] as Array).erase(id)
	(sel["enabled_sets"] if enabled else sel["disabled_sets"]).append(id)
	save_selection(sel)


static func is_question_enabled(set_id: String, question_id: String, sel: Dictionary = {}) -> bool:
	if sel.is_empty():
		sel = load_selection()
	var off: Variant = (sel["disabled_questions"] as Dictionary).get(set_id, [])
	return not (off as Array).has(question_id)


static func set_question_enabled(set_id: String, question_id: String, enabled: bool) -> void:
	var sel := load_selection()
	var dq: Dictionary = sel["disabled_questions"]
	var off: Array = dq.get(set_id, [])
	off.erase(question_id)
	if not enabled:
		off.append(question_id)
	if off.is_empty():
		dq.erase(set_id)
	else:
		dq[set_id] = off
	save_selection(sel)


## Po usunięciu zestawu — porządek w wyborze.
static func forget_set(id: String) -> void:
	var sel := load_selection()
	(sel["enabled_sets"] as Array).erase(id)
	(sel["disabled_sets"] as Array).erase(id)
	(sel["disabled_questions"] as Dictionary).erase(id)
	save_selection(sel)


# --- Pomocnicze --------------------------------------------------------------------------------------

static func _json_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f)
	return out


static func _read_set(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Array:
		return {"name": path.get_file().get_basename(), "description": "", "questions": data}
	if data is Dictionary and (data as Dictionary).has("questions"):
		var d := (data as Dictionary).duplicate(true)
		d["name"] = str(d.get("name", path.get_file().get_basename()))
		d["description"] = str(d.get("description", ""))
		return d
	return {}


static func _slug(text: String) -> String:
	var map := {"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ź": "z", "ż": "z"}
	var out := ""
	for ch in text.to_lower():
		ch = map.get(ch, ch)
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("_") and out != "":
			out += "_"
	return out.trim_suffix("_").left(40)
