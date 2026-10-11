extends PanelContainer
class_name QuizRpgFrame

## Ramka sekcji w oknie (theme_type_variation QuizFrame — styl okna z motywu, np. tekstura z paczki UI). Opakowuje jedną sekcję
## (nagłówek postaci, listę, wiersz akcji); kod ekranu przełącza widoczność samej sekcji, więc ramka podąża za nią
## (inaczej zostawałaby pusta ramka po ukryciu zawartości).


func _ready() -> void:
	child_entered_tree.connect(_bind)
	for c in get_children():
		_bind(c)


func _bind(node: Node) -> void:
	if node is Control and not (node as Control).visibility_changed.is_connected(_sync):
		(node as Control).visibility_changed.connect(_sync)
	_sync()


func _sync() -> void:
	for c in get_children():
		if c is Control:
			visible = (c as Control).visible
			return
