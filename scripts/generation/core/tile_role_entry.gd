class_name TileRoleEntry
extends Resource

## Wpis łączący rolę logiczną generatora z grafiką.
## Kompatybilność: variants puste -> użyj legacy `tile`; variants niepuste -> wybierz
## jeden wariant i użyj wszystkich jego części.

@export var role: TileRole.Id = TileRole.Id.NONE

## Legacy: pojedynczy kafelek. NIE usuwać w Fazie 2 (kompatybilność wstecz).
@export var tile: TileRef

## Nowy model: warianty wizualne / moduły wielokaflowe.
@export var variants: Array[TileVariant] = []

@export var display_name: String = ""
@export_multiline var description: String = ""

## Czy wpis korzysta z nowego modelu wariantów.
func has_variants() -> bool:
	return not variants.is_empty()
