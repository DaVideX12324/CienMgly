class_name QuizRpgLevelMusic
extends Node

## Muzyka mapy: wstaw ten węzeł do sceny poziomu (ręcznego albo generowanego) i przeciągnij plik (.ogg) w Inspektorze.
## Ma pierwszeństwo przed music_track korzenia i "music" z JSON-a mapy (LevelManager._play_level_music).

@export var music: AudioStream
