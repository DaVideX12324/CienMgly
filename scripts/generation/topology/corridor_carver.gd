class_name CorridorCarver
extends RefCounted


func carve(_ctx: GenerationContext, _from: Vector2i, _to: Vector2i, _width: int) -> void:
	push_error("CorridorCarver.carve() must be overridden")
