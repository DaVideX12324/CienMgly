class_name EdgeKind
extends RefCounted

## Typy geometryczne krawędzi zgodnie ze specyfikacją §9.2 refaktoru.
enum Kind {
	NONE = 0,
	FLOOR,              # Komórka przechodnia (warstwa Floor)
	SOLID_FILL,         # Lita skała, brak kontaktu z podłogą wymagającego modułu
	SIDE_WALL,          # Ściana pionowa (podłoga po jednej stronie w poziomie)
	FACADE,             # Fasada południowa (podłoga pod, ściana nad)
	CONNECTOR,          # Łącznik zmiany wysokości fasady (2H <-> 3H)
	STEP,               # Schodek fasady (sąsiad na innej wysokości)
	SLOPE,              # Skos fasady (cienki schodek dy=1)
	TOP_RIM,            # Szczyt ściany widziany z góry
	OUT_CORNER,         # Wypukłe zakończenie fasady (koniec masywu)
	INNER_CORNER,       # Wklęsły narożnik / domknięcie schodka
	PILLAR,             # ZAREZERWOWANE — Etap 10
	NICHE,              # Wnęka dekoracyjna (para kolumn)
	PORTAL_CLEAR        # Komórka portalu — kafel usuwany
}

enum Orientation {
	NONE = 0,
	NORTH,
	SOUTH,
	WEST,
	EAST,
	NORTH_WEST,
	NORTH_EAST,
	SOUTH_WEST,
	SOUTH_EAST
}

enum SegmentKind {
	NONE = 0,
	SINGLE,
	START,
	MIDDLE,
	END
}
