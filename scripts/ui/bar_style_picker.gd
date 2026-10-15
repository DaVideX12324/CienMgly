extends GridContainer
## Wybór stylu pasków w opcjach (zakładka „Motyw” hosta, module_root.create_bar_style_picker): kafelek na styl
## (scena bar_style_cell.tscn) z nazwą i podglądem pasków HP / SP / TP w tym stylu (QuizTheme.bar_preview_theme).
## Kliknięty kafelek -> style_selected; zapis ustawienia robi okno opcji.

signal style_selected(style_id: String)

const CellScene: PackedScene = preload("../../scenes/ui/bar_style_cell.tscn")

var _group := ButtonGroup.new()
var _font_size := 16


## Kafelki stylów [{id, name}]; zaznaczony `current` (pusty = domyślny styl).
func setup(styles: Array, current: String, font_size: int = 16) -> void:
	_font_size = font_size
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var cur := current if current != "" else QuizTheme.DEFAULT_BAR_STYLE
	for st in styles:
		var id := str(st.get("id", ""))
		var cell := CellScene.instantiate() as Button
		cell.name = "Cell_" + id
		cell.button_group = _group
		cell.theme = QuizTheme.bar_preview_theme(id)
		cell.tooltip_text = str(st.get("name", id))
		var lbl := cell.get_node("%Name") as Label
		lbl.text = str(st.get("name", id))
		lbl.add_theme_font_size_override("font_size", _font_size)
		cell.button_pressed = id == cur
		cell.pressed.connect(func() -> void: style_selected.emit(id))
		add_child(cell)


## Podglądy od nowa (zmiana motywu okien zmienia ramkę gładkich pasków).
func refresh_previews() -> void:
	for cell in get_children():
		var id := String(cell.name).trim_prefix("Cell_")
		(cell as Control).theme = QuizTheme.bar_preview_theme(id)
