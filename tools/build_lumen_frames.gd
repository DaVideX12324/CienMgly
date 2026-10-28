extends SceneTree
## Arkusze postaci z generatora gen_lumen_character.py (assets/lumenlore/characters/<postać>/<Animacja>.png, klatki
## 64×64, rzędy E/NE/N/NW/W/SW/S/SE) -> SpriteFrames resources/heroes/frames/ll_<postać>_frames.tres:
## <stan>_<kierunek> dla 8 kierunków (right, up_right, up, up_left, left, down_left, down, down_right); idle / walk / run
## w pętli, death / punch bez; "idle" i "walk" = dół (NPC, zapas).
## Uruchomienie: godot --headless --path . -s res://modules/quiz_rpg/tools/build_lumen_frames.gd [-- postać ...]
const CHARS := ["bohater", "kaplan", "lotrzyk", "mag"]
const DIRS := ["right", "up_right", "up", "up_left", "left", "down_left", "down", "down_right"]
const ACTIONS := {"idle": ["Idle", 6.0], "walk": ["Walk", 10.0], "run": ["Run", 12.0], "death": ["Death", 10.0], "punch": ["Punch", 14.0]}
const LOOPED := ["idle", "walk", "run"]
const FRAME := 64


func _initialize() -> void:
	var chars: Array = Array(OS.get_cmdline_user_args()) if not OS.get_cmdline_user_args().is_empty() else CHARS
	for ch: String in chars:
		var sf := SpriteFrames.new()
		sf.remove_animation(&"default")
		for action: String in ACTIONS:
			var tex := load("res://assets/lumenlore/characters/%s/%s.png" % [ch, ACTIONS[action][0]]) as Texture2D
			if tex == null:
				push_error("brak arkusza %s / %s" % [ch, action])
				continue
			var n := int(tex.get_width() / FRAME)
			for r in DIRS.size():
				var names: Array = [action + "_" + DIRS[r]]
				if DIRS[r] == "down" and action in ["idle", "walk"]:
					names.append(action)
				for anim: String in names:
					sf.add_animation(anim)
					sf.set_animation_speed(anim, ACTIONS[action][1])
					sf.set_animation_loop(anim, action in LOOPED)
					for i in n:
						var at := AtlasTexture.new()
						at.atlas = tex
						at.region = Rect2(i * FRAME, r * FRAME, FRAME, FRAME)
						sf.add_frame(anim, at)
		var out := "res://modules/quiz_rpg/resources/heroes/frames/ll_%s_frames.tres" % ch
		print(out, " ", error_string(ResourceSaver.save(sf, out)))
	quit()
