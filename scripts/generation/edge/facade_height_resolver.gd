class_name FacadeHeightResolver
extends RefCounted

## Czysty resolver geometryczny wysokości fasad (§4.6).
## Rozstrzyga wyłącznie na podstawie solid_depth:
## - solid_depth >= 3 -> Height.H3
## - solid_depth == 2 -> Height.H2
## - wpp (w tym solid_depth == 1) -> Height.INVALID

enum Height {
	INVALID = 0,
	H2 = 2,
	H3 = 3
}

static func resolve(solid_depth: int) -> int:
	if solid_depth >= 3:
		return Height.H3
	if solid_depth == 2:
		return Height.H2
	return Height.INVALID
