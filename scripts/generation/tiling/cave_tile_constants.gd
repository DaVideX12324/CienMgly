class_name CaveTileConstants
extends RefCounted

# --- Koordynaty kafelków w atlasie caves.tres (Tiles.png) ---

# Ściany zwykłe (Standard Walls):
const WALL_TOP: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0)]
const WALL_TOP_CORNER_LEFT := Vector2i(0, 1)   # Kafelek 5 (RED B5)
const WALL_TOP_CORNER_RIGHT := Vector2i(5, 1)  # Kafelek 8 (RED mirror B5)
const WALL_TOP_SLOPE_RIGHT := Vector2i(4, 1)   # Kafelek 7 (BLUE mirror B5)
const WALL_TOP_SLOPE_LEFT := Vector2i(1, 1)    # Kafelek 6 (BLUE B5)

# Ściany boczne (pionowe)
const WALL_SIDE_WEST: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3)]
const WALL_SIDE_EAST: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 3)]
const WALL_LEFT: Array[Vector2i] = WALL_SIDE_WEST
const WALL_RIGHT: Array[Vector2i] = WALL_SIDE_EAST

# Fasada prosta 3H (wiersze 5, 6, 7)
const WALL_BOTTOM_TOP: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5)]
const WALL_BOTTOM_MID: Array[Vector2i] = [Vector2i(2, 6), Vector2i(3, 6)]
const WALL_BOTTOM_BASE: Array[Vector2i] = [Vector2i(2, 7), Vector2i(3, 7)]

# Moduł schodka prawego / skos opadający w dół w prawo (MOD_CRNR_NW_IN): kolumna 1
const MOD_CRNR_NW_IN_TOP := Vector2i(1, 5)
const MOD_CRNR_NW_IN_MID := Vector2i(1, 6)
const MOD_CRNR_NW_IN_BASE := Vector2i(1, 7)

# Moduł zakończenia lewego bez schodka (MOD_CRNR_NW_OUT): kolumna 0
const MOD_CRNR_NW_OUT_TOP := Vector2i(0, 4)
const MOD_CRNR_NW_OUT_MID := Vector2i(0, 5)
const MOD_CRNR_NW_OUT_BASE := Vector2i(0, 6)

# Moduł schodka lewego / skos opadający w dół w lewo (MOD_CRNR_NE_IN): kolumna 4
const MOD_CRNR_NE_IN_TOP := Vector2i(4, 5)
const MOD_CRNR_NE_IN_MID := Vector2i(4, 6)
const MOD_CRNR_NE_IN_BASE := Vector2i(4, 7)

# Moduł zakończenia prawego bez schodka (MOD_CRNR_NE_OUT): kolumna 5
const MOD_CRNR_NE_OUT_TOP := Vector2i(5, 4)
const MOD_CRNR_NE_OUT_MID := Vector2i(5, 5)
const MOD_CRNR_NE_OUT_BASE := Vector2i(5, 6)

# Aliasy modułów:
const WALL_BOTTOM_TOP_LEFT := MOD_CRNR_NW_IN_TOP
const WALL_BOTTOM_MID_LEFT := MOD_CRNR_NW_IN_MID
const WALL_BOTTOM_BASE_LEFT := MOD_CRNR_NW_IN_BASE
const WALL_BOTTOM_TOP_RIGHT := MOD_CRNR_NE_IN_TOP
const WALL_BOTTOM_MID_RIGHT := MOD_CRNR_NE_IN_MID
const WALL_BOTTOM_BASE_RIGHT := MOD_CRNR_NE_IN_BASE

# Ściany z korzeniami / kolcami (Root & Thorn Walls):
const ROOT_TOP_TIPS: Array[Vector2i] = [Vector2i(2, 8), Vector2i(3, 8)]
const ROOT_TOP_BASE: Array[Vector2i] = [Vector2i(2, 9), Vector2i(3, 9)]

const ROOT_TOP_TIPS_LEFT := Vector2i(1, 8)
const ROOT_TOP_BASE_LEFT := Vector2i(1, 9)
const ROOT_TOP_TIPS_RIGHT := Vector2i(4, 8)
const ROOT_TOP_BASE_RIGHT := Vector2i(4, 9)

const ROOT_TOP_SLOPE_TIPS_RIGHT := Vector2i(5, 9)
const ROOT_TOP_SLOPE_BASE_RIGHT := Vector2i(5, 10)
const ROOT_TOP_SLOPE_TIPS_LEFT := Vector2i(0, 9)
const ROOT_TOP_SLOPE_BASE_LEFT := Vector2i(0, 10)

const ROOT_WALL_SIDE_WEST: Array[Vector2i] = [Vector2i(5, 11), Vector2i(5, 12)]
const ROOT_WALL_SIDE_EAST: Array[Vector2i] = [Vector2i(0, 11), Vector2i(0, 12)]
const ROOT_WALL_LEFT: Array[Vector2i] = ROOT_WALL_SIDE_WEST
const ROOT_WALL_RIGHT: Array[Vector2i] = ROOT_WALL_SIDE_EAST

const ROOT_BOTTOM_TOP: Array[Vector2i] = [Vector2i(2, 14), Vector2i(3, 14)]
const ROOT_BOTTOM_MID: Array[Vector2i] = [Vector2i(2, 15), Vector2i(3, 15)]
const ROOT_BOTTOM_BASE: Array[Vector2i] = [Vector2i(2, 16), Vector2i(3, 16)]

const ROOT_MOD_CRNR_NW_IN_TOP := Vector2i(1, 14)
const ROOT_MOD_CRNR_NW_IN_MID := Vector2i(1, 15)
const ROOT_MOD_CRNR_NW_IN_BASE := Vector2i(1, 16)

const ROOT_MOD_CRNR_NW_OUT_TOP := Vector2i(0, 13)
const ROOT_MOD_CRNR_NW_OUT_MID := Vector2i(0, 14)
const ROOT_MOD_CRNR_NW_OUT_BASE := Vector2i(0, 15)

const ROOT_MOD_CRNR_NE_IN_TOP := Vector2i(4, 14)
const ROOT_MOD_CRNR_NE_IN_MID := Vector2i(4, 15)
const ROOT_MOD_CRNR_NE_IN_BASE := Vector2i(4, 16)

const ROOT_MOD_CRNR_NE_OUT_TOP := Vector2i(5, 13)
const ROOT_MOD_CRNR_NE_OUT_MID := Vector2i(5, 14)
const ROOT_MOD_CRNR_NE_OUT_BASE := Vector2i(5, 15)

const ROOT_BOTTOM_TOP_LEFT := ROOT_MOD_CRNR_NW_IN_TOP
const ROOT_BOTTOM_MID_LEFT := ROOT_MOD_CRNR_NW_IN_MID
const ROOT_BOTTOM_BASE_LEFT := ROOT_MOD_CRNR_NW_IN_BASE
const ROOT_BOTTOM_TOP_RIGHT := ROOT_MOD_CRNR_NE_IN_TOP
const ROOT_BOTTOM_MID_RIGHT := ROOT_MOD_CRNR_NE_IN_MID
const ROOT_BOTTOM_BASE_RIGHT := ROOT_MOD_CRNR_NE_IN_BASE

# Narożniki wewnętrzne Foot:
const CRNR_SW_IN := Vector2i(4, 4)
const ROOT_CRNR_SW_IN := Vector2i(4, 13)
const CRNR_SE_IN := Vector2i(1, 4)
const ROOT_CRNR_SE_IN := Vector2i(1, 13)

const CORNER_INNER_TOP_LEFT := CRNR_SW_IN
const ROOT_CORNER_INNER_TOP_LEFT := ROOT_CRNR_SW_IN
const CORNER_INNER_TOP_RIGHT := CRNR_SE_IN
const ROOT_CORNER_INNER_TOP_RIGHT := ROOT_CRNR_SE_IN

const CORNER_INNER_BOTTOM_LEFT := Vector2i(4, 1)
const ROOT_CORNER_INNER_BOTTOM_LEFT := Vector2i(4, 10)
const CORNER_INNER_BOTTOM_RIGHT := Vector2i(1, 1)
const ROOT_CORNER_INNER_BOTTOM_RIGHT := Vector2i(1, 10)

# Lita skała i void:
const WALL_INSIDE := Vector2i(2, 2)
const WALL_INSIDE_ALT := Vector2i(2, 3)
const WALL_INSIDE_ALT2 := Vector2i(3, 2)

# Fasady 2H:
const WALL_2H_TOP: Array[Vector2i] = [Vector2i(2, 20), Vector2i(3, 20)]
const WALL_2H_BASE: Array[Vector2i] = [Vector2i(2, 21), Vector2i(3, 21)]

const WALL_2H_WEST_TOP := Vector2i(0, 19)
const WALL_2H_WEST_BASE := Vector2i(0, 20)
const WALL_2H_EAST_TOP := Vector2i(5, 19)
const WALL_2H_EAST_BASE := Vector2i(5, 20)

const WALL_2H_SLOPE_LEFT_TOP := Vector2i(1, 19)
const WALL_2H_SLOPE_LEFT_MID := Vector2i(1, 20)
const WALL_2H_SLOPE_LEFT_BASE := Vector2i(1, 21)

const WALL_2H_SLOPE_RIGHT_TOP := Vector2i(4, 19)
const WALL_2H_SLOPE_RIGHT_MID := Vector2i(4, 20)
const WALL_2H_SLOPE_RIGHT_BASE := Vector2i(4, 21)

# Łączniki 2H <-> 3H:
const CONNECTOR_2H_TO_3H_TOP := Vector2i(7, 19)
const CONNECTOR_2H_TO_3H_MID := Vector2i(7, 20)
const CONNECTOR_2H_TO_3H_BASE := Vector2i(7, 21)

const CONNECTOR_3H_TO_2H_TOP := Vector2i(10, 19)
const CONNECTOR_3H_TO_2H_MID := Vector2i(10, 20)
const CONNECTOR_3H_TO_2H_BASE := Vector2i(10, 21)

# Bazowy kafel podłogi:
const FLOOR_BASE_TILE := Vector2i(10, 13)
