class_name EdgeContext
extends RefCounted


var pos: Vector2i = Vector2i.ZERO

# --- Sąsiedztwo 3x3 (true = przechodnie / podłoga) ---
var n_floor: bool = false
var ne_floor: bool = false
var e_floor: bool = false
var se_floor: bool = false
var s_floor: bool = false
var sw_floor: bool = false
var w_floor: bool = false
var nw_floor: bool = false

# --- Podsumowanie kardynalne ---
var floor_cardinal_count: int = 0
var wall_cardinal_count: int = 0
var neighborhood_mask: int = 0          # N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128

# --- Klasyfikacja geometryczna ---
var edge_kind: int = EdgeKind.Kind.NONE
var orientation: int = EdgeKind.Orientation.NONE
var facade_height: int = 0              # 0 = nie dotyczy, 2 = 2H, 3 = 3H
var solid_depth: int = 0                # Zmierzona głębokość litej ściany (1..6)

# --- Segment poziomy ---
var segment_kind: int = EdgeKind.SegmentKind.NONE
var segment_index: int = -1

# --- Kontekst specjalny ---
var in_portal_zone: bool = false
var step_dy: int = 0

# --- Adnotacje nisz (geometryczna kandydatura w Etapie 4) ---
var is_niche_candidate: bool = false
var is_secret_niche_candidate: bool = false
var niche_partner: Vector2i = Vector2i(-1, -1)

# --- Sąsiedztwo z fasadą 2H (dla RimPlacer) ---
var touches_2h_facade_left: bool = false
var touches_2h_facade_right: bool = false

# --- Ochrona litej skały przed wstrzykiwaniem kafelków krawędziowych ---
var is_protected_solid: bool = false
