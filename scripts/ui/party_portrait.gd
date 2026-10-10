extends RefCounted
class_name QuizRpgPartyPortrait

## Miniaturka postaci drużyny do menu: member["portrait"], a bez niej pierwsza klatka animacji idle postaci
## (SpriteFrames z HeroData.sprite_frames albo z AnimatedSprite2D w HeroData.actor_scene) przycięta do treści;
## head_only — kwadrat z górnej części sylwetki (głowa). Wyniki w pamięci podręcznej (raz na postać i tryb).

## Część wysokości sylwetki uznawana za głowę (head_only) i górne wiersze, po których środkujemy głowę
## (broń obok postaci nie przesuwa kadru).
const HEAD_FRACTION := 0.68
const HEAD_CENTER_ROWS := 0.3

static var _cache: Dictionary = {}


static func for_member(member: Dictionary, hero: QuizRpgHeroData, head_only: bool) -> Texture2D:
	var own: Variant = member.get("portrait")
	if own is Texture2D:
		return own
	if hero != null and hero.portrait != null:
		return hero.portrait
	var frames: SpriteFrames = hero.sprite_frames if hero != null else null
	if frames == null and hero != null:
		frames = _frames_from_scene(hero.actor_scene)
	if frames == null:
		return null
	var key := "%d:%s" % [frames.get_instance_id(), head_only]
	if _cache.has(key):
		return _cache[key]
	var tex := _idle_frame(frames, head_only)
	_cache[key] = tex
	return tex


static func _frames_from_scene(scene: PackedScene) -> SpriteFrames:
	if scene == null:
		return null
	var st := scene.get_state()
	for i in st.get_node_count():
		if str(st.get_node_type(i)) != "AnimatedSprite2D":
			continue
		for p in st.get_node_property_count(i):
			if st.get_node_property_name(i, p) == &"sprite_frames":
				return st.get_node_property_value(i, p) as SpriteFrames
	return null


## Pierwsza klatka animacji idle (idle_down / idle / pierwsza z „idle” w nazwie, inaczej pierwsza animacja),
## przycięta do nieprzezroczystych pikseli.
static func _idle_frame(frames: SpriteFrames, head_only: bool) -> Texture2D:
	var names := frames.get_animation_names()
	if names.is_empty():
		return null
	var anim: StringName = names[0]
	for want in [&"idle_down", &"idle"]:
		if frames.has_animation(want):
			anim = want
			break
	if anim == names[0]:
		for n in names:
			if String(n).contains("idle"):
				anim = n
				break
	if frames.get_frame_count(anim) == 0:
		return null
	var src := frames.get_frame_texture(anim, 0)
	var img := src.get_image() if src else null
	if img == null or img.is_empty():
		return src
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return src
	var rect := used
	if head_only:
		var h := maxi(int(ceil(used.size.y * HEAD_FRACTION)), 1)
		var cx := _top_center_x(img, used, maxi(int(ceil(used.size.y * HEAD_CENTER_ROWS)), 1))
		rect = Rect2i(cx - h / 2, used.position.y, h, h)
	# kwadrat (miniaturka nie rozciąga się w poziomie / pionie)
	var side := maxi(rect.size.x, rect.size.y)
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	var src_rect := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var dst := Vector2i((side - rect.size.x) / 2, side - rect.size.y if not head_only else 0) + (src_rect.position - rect.position)
	img.convert(Image.FORMAT_RGBA8)
	square.blit_rect(img, src_rect, dst)
	return ImageTexture.create_from_image(square)


## Środek w poziomie nieprzezroczystych pikseli w `rows` górnych wierszach sylwetki.
static func _top_center_x(img: Image, used: Rect2i, rows: int) -> int:
	var lo := used.end.x
	var hi := used.position.x
	for y in range(used.position.y, mini(used.position.y + rows, used.end.y)):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.1:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return (lo + hi + 1) / 2 if hi >= lo else used.position.x + used.size.x / 2
