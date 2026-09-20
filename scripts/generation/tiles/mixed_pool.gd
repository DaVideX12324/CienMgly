class_name MixedPool
extends Resource

## Pula MIXED: pseudo-zestaw, który per moduł losuje (deterministycznie) jeden z
## kompatybilnych named setów `sources`. NIE jest rodziną kafli w atlasie — to tryb
## selekcji. Źródła MUSZĄ być wzajemnie zgodne (reguła ALLOWED) — sprawdza walidacja.

@export var id: StringName
@export var sources: Array[StringName] = []
