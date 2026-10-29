@tool
class_name QuizRpgFootstepSet
extends Resource

## Zestaw dźwięków kroków dla jednego typu podłoża (jak FootstepSFXSet w Amon-Ra). Typ podłoża pod stopami ustala
## Footsteps: dana kafla „ground_type” (warstwa danych TileSetu, jeśli jest), inaczej nazwa terenu kafla — pierwszy
## zestaw, którego słowo kluczowe zawiera się w nazwie terenu (małe litery).

@export var ground_type: String = "ground"
## Słowa w nazwie terenu TileSetu oznaczające ten typ, np. ["grass", "foliage"] (Tall grass, Dry grass też pasują).
@export var terrain_keywords: PackedStringArray = []
@export var sounds: Array[AudioStream] = []
## Korekta głośności zestawu względem Footsteps.volume_db.
@export var volume_offset_db: float = 0.0


func random_sound() -> AudioStream:
	return null if sounds.is_empty() else sounds[randi() % sounds.size()]
