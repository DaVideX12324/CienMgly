class_name TopologyGenerator
extends RefCounted

const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")

func generate(_ctx: GenerationContext) -> void:
	push_error("TopologyGenerator.generate() must be overridden")
