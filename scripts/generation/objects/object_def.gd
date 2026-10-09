@tool
class_name ObjectDef
extends RefCounted

## Definicja obiektu z katalogu (JSON: grupa + obiekt, scalone w ObjectCatalog). Czyste dane —
## ObjectPlanner decyduje, gdzie stoi, ObjectRealizer — jak powstaje (kafel / canvas item / scena).
##
## Pozycja obiektu: kratka kotwicy `cell` = lewa-dolna kratka podstawy (footprintu). Punkt obiektu
## w px (y-sort, kolizja, scena) = środek dolnej krawędzi podstawy (+ przesunięcie jitter/free).

enum Klass { DECAL, PROP, INTERACTIVE }
enum Placement { GRID, GRID_JITTER, FREE }
enum Collision { NONE, TILE, SHAPE, SCENE }

const CELL := 16

var id: StringName = &""
var group: StringName = &""
var klass: Klass = Klass.DECAL
var placement: Placement = Placement.GRID
var jitter_px: float = 4.0            # grid_jitter: maks. przesunięcie w każdej osi
var spacing: int = 1                  # grid/grid_jitter: min. odstęp kotwic tego obiektu (kratki, Chebyshev)
var spacing_px: float = 16.0          # free: min. odstęp punktów tego obiektu (px)
var density: float = 0.0              # sztuk na 100 kratek-kandydatów
var count_min: int = -1               # count: [min, max] — stała liczba zamiast gęstości (-1 = gęstość)
var count_max: int = -1
var atlas: Array[Vector2i] = []       # warianty grafiki (atlas coords w TileSecie poziomu)
var source_id: int = 0                # źródło atlasu TileSetu ("source")
## Moduł z kilku kafli ("tiles": [[dx, dy, x, y], …], dy <= 0): {off: Vector2i, coords: Vector2i}.
## Jeden wariant; kafle kładzione wprost (bez odbicia).
var tiles: Array[Dictionary] = []
var size := Vector2i.ONE              # rozmiar sprite'a w kratkach (w × h), dół = wiersz kotwicy
var footprint: Array[Vector2i] = []   # kratki podstawy względem kotwicy (y <= 0)
var scene: String = ""                # pierwsza scena: INTERACTIVE — ścieżka res:// albo alias (np. "chest")
var scenes: Array[String] = []        # warianty ze scen (DECAL/PROP): "scene": "a.tscn" albo ["a.tscn", "b.tscn"]
var bakes: Array[ObjectBake] = []     # wypieczone sceny wariantów (DECAL/PROP)
var collision: Collision = Collision.NONE
var shape_rect := Vector2.ZERO        # kształt kolizji (px): prostokąt w × h …
var shape_radius: float = 0.0         # … albo koło
var shape_offset := Vector2.ZERO      # przesunięcie kształtu względem punktu obiektu
var visual_rect := Rect2()            # obrys grafiki względem punktu obiektu (px; z odbiciem, gdy flip_h)
var context: Array[StringName] = []   # tagi kontekstu — wystarczy jeden (OR); pusto = bez wymagań
var avoid: Array[StringName] = []     # tagi wykluczające
var require: Array[StringName] = []   # tagi wymagane WSZYSTKIE (AND) — np. ["room"] + context ["wall_any"]
var prefer: Array[StringName] = []    # tagi próbowane najpierw (nisza, ślepy zaułek…), potem reszta
var per_room: float = 0.0             # >0: w każdym pokoju poza portalowymi szansa na 1 sztukę (zamiast density)
var force_big: bool = false            # katalog "big": licz jako duży obiekt (wagi obszarów, zestawy) mimo rozmiaru
## Grupa wyłączności w pomieszczeniu (per_room / per_chamber): obiekty z tą samą grupą — najwyżej jeden na pokój /
## komnatę (np. stoły różnej szerokości). Pusta = bez ograniczenia.
var room_group: StringName = &""
var per_chamber: float = 0.0          # jak per_room, ale w komnatach za ścianami działowymi (canals.chambers)
var room_density: float = 0.0         # dodatkowe sztuki na 100 kandydatów w pokojach (poza portalowymi) i komnatach
                                      # (podłoga; obiekty lica — na licu nad nimi)
var levels: Array[StringName] = []    # "ground" / "plateau" / "pit"; pusto = każda wysokość
var terrain: Array[StringName] = []   # "grass" / "mud" / "plain" (goła podłoga); pusto = każdy teren
var terrain_margin: int = 0           # ten sam teren w promieniu (Chebyshev) — z dala od brzegu plamy
var cluster_min: int = 0              # cluster: {"size": [a, b], "radius": r} — skupiska
var cluster_max: int = 0
## cluster.patterns: id winiet (ObjectCatalog.vignettes) jako gotowe kształty skupiska — z szansą
## cluster.pattern_chance skupisko próbuje najpierw winiety pasującej w kratce zarodka, inaczej losowe.
var cluster_patterns: Array[StringName] = []
var cluster_pattern_chance: float = 0.0
var cluster_radius: int = 0
var companions: Array[Dictionary] = [] # {id: StringName, min, max, radius} — dostawiane wokół każdej sztuki
var keep_paths: bool = true           # z kolizją: nie na zarezerwowanych przejściach
var priority: int = 0                 # większy = rozmieszczany wcześniej
var flip_h: bool = false              # losowe odbicie (canvas item / scena)
## Stos: obiekt z kafla, za którym (kratkę niżej) stoi inny obiekt ze stack — kafel alternatywny STACK_ALT
## (y-sort podniesiony o kratkę): rysuje się nad tym z przodu, podstawa nakrywa jego górę (skrzynia na skrzyni).
var stack: bool = false
## Zestaw (np. "dining", "storage") — duże obiekty z różnych zestawów trzymają odstęp (katalog: set_gap),
## więc przy stole stoją krzesła, a nie skrzynki. Pusto = bez zestawu (bez ograniczeń).
var set_id: StringName = &""
## Minimalna liczba wolnych kratek między obiektem (podstawa i rysunek) a wodą kanału; 0 = bez reguły.
var canal_gap: int = 0
## Kierunek, w którym zwrócony jest każdy wariant ("N" / "S" / "E" / "W", "" = bez kierunku); odbicie poziome
## zamienia E <-> W. Pusto = warianty bez kierunków.
var facing: Array[StringName] = []
## Preferowane kierunki (waga dodawana do 1 przy losowaniu wariantu i odbicia): "parent" — przodem do rodzica
## (towarzysz, np. krzesło do stołu), "wall" / "away_wall" — do najbliższej ściany / od niej, "N" / "S" / "E" /
## "W" — stały kierunek. Inne kierunki zostają możliwe, tylko rzadsze.
var facing_pref: Dictionary = {}  # StringName -> float
const STACK_ALT := 1
var order: int = 0                    # kolejność w pliku (remisy priorytetu)
## Montaż: "" = na podłodze (ObjectPlanner); "facade" = na licu ściany widocznym z południa
## (WallDecorPlanner) — kotwica = dolna kratka lica nad podłogą, bez kolizji i zajętości.
var mount: StringName = &""
## Na licu: rytm filarów — odstępy (przęsła w kratkach) do wyboru na odcinek lica; pusto = zwykłe losowanie.
var rhythm: Array[int] = []
## Rytm: szansa filarów na odcinku wg rodzaju obszaru pod nim (canals.areas: "hall" / "room" / "corridor");
## brak rodzaju = 1.0 (zawsze).
var rhythm_area_chance: Dictionary = {}  # StringName -> float
## Na licu: ozdoba przęsła — na ścianach z filarami jedna na przęsło wg wzoru (facade_rhythm.patterns),
## zamiast losowego rozrzutu.
var span: bool = false
## Na licu: ozdoba filara (np. łańcuch z hakiem) — na filarach ściany (kotwica = kotwica filara), na ścianie
## z szansą density (0..1, cała ściana naraz); tylko filary sięgające najwyższego kafla ozdoby.
var on_pillar: bool = false
## Na podłodze: ozdoba posadzki w osi przęseł (np. rząd otworów) — WallDecorPlanner kładzie ją pod każdym
## przęsłem ściany z filarami (z szansą density na ścianę), kratkę przed licem; ObjectPlanner jej nie losuje.
var span_floor: bool = false
## Na licu: szansa na sztukę nad północnym końcem kanału (kanał „wpływa w ścianę"), gdy szerokość obiektu = szerokość
## kanału; WallDecorPlanner stawia ją przed rytmem filarów, wyśrodkowaną nad wodą.
var canal_end: float = 0.0
var canal_end_dy: int = 0              # przesunięcie obiektu nad końcem kanału w pionie (+1 = kratkę niżej)
## Nad jakim końcem kanału: &"any" (każdym), &"wet_open" (otwartym z wodą — kwas pod ścianę, np. krata zatopiona),
## &"dry" (pustego koryta — zamkniętego licem kanału, np. krata na licu kanału).
var canal_end_on: StringName = &"any"
## Na licu: tylko lico tej wysokości (3 / 4 — odcinki 4H jak w FacadePlacer); 0 = każde.
var facade_h: int = 0
## Kafle obiektu na osobnej warstwie poziomu (np. "WallDecor" — filary nad licem); pusto = Decals / Props.
var layer_name: StringName = &""


func is_wall_mounted() -> bool:
	return mount == &"facade" or mount == &"rim"


## Na krawędzi ściany od strony podłogi na północ (rim północny), np. filar widziany od tyłu.
func is_rim_mounted() -> bool:
	return mount == &"rim"


func is_solid() -> bool:
	return collision != Collision.NONE


## Duży obiekt: z kolizją (PROP) i wielokratkowy (sprite / podstawa > 1 kratka) albo z kształtem kolizji na
## >= 80 % kratki. Takie obiekty planer stawia głównie w pokojach (katalog: area_weights).
func is_big() -> bool:
	if force_big:
		return true
	if not is_solid() or klass != Klass.PROP:
		return false
	if size.x * size.y > 1 or footprint.size() > 1:
		return true
	var area := shape_rect.x * shape_rect.y if shape_radius <= 0.0 else PI * shape_radius * shape_radius
	return area >= 0.8 * CELL * CELL


## Obiekt większy niż jedna kratka — podstawa na kilku kratkach albo grafika szersza / wyższa niż
## 1,5 kratki (drobna dekoracja lekko wystająca poza kratkę się nie liczy). Nie może zakrywać ścian.
func is_large() -> bool:
	return footprint.size() > 1 or visual_rect.size.x > CELL * 1.5 or visual_rect.size.y > CELL * 1.5


func footprint_size() -> Vector2i:
	var mx := 0
	var my := 0
	for f in footprint:
		mx = maxi(mx, f.x)
		my = maxi(my, -f.y)
	return Vector2i(mx + 1, my + 1)


## Punkt obiektu (px) dla kotwicy `cell`: środek dolnej krawędzi podstawy.
func base_point(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + footprint_size().x * 0.5) * CELL, (cell.y + 1) * CELL)


## Liczba wariantów grafiki (atlas albo sceny).
func variant_count() -> int:
	return maxi(maxi(atlas.size(), scenes.size()), 1 if not tiles.is_empty() else 0)


## Czy obiekt rysowany jest kaflem (siatka + grafika z atlasu), a nie canvas itemem / sceną.
func renders_as_tile() -> bool:
	return klass != Klass.INTERACTIVE and placement == Placement.GRID and scenes.is_empty() and (not atlas.is_empty() or not tiles.is_empty())
