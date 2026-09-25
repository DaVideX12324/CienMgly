class_name ObjectRuntime
extends Node

## Zasoby serwerów po ObjectRealizerze (canvas items, body i kształty fizyki) — nie są węzłami,
## więc ktoś musi je zwolnić: przy regeneracji (clear) i przy usunięciu poziomu (PREDELETE).

var items: Array[RID] = []
var bodies: Array[RID] = []
var shapes: Array[RID] = []
var counts := {"tiles": 0, "items": 0, "shapes": 0, "scenes": 0}


func clear() -> void:
	for rid in items:
		RenderingServer.free_rid(rid)
	for rid in bodies:
		PhysicsServer2D.free_rid(rid)
	for rid in shapes:
		PhysicsServer2D.free_rid(rid)
	items.clear()
	bodies.clear()
	shapes.clear()
	for k in counts:
		counts[k] = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear()
