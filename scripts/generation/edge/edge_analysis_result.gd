class_name EdgeAnalysisResult
extends RefCounted

## Słownik wszystkich sklasyfikowanych komórek: Vector2i -> EdgeContext
var edges: Dictionary = {}

## Słownik stóp fasad: int (kolumna x) -> Array[int] (wiersze y stóp fasad)
var facade_cols: Dictionary = {}

## Posortowana rosnąco lista kolumn fasad
var sorted_xs: Array = []

## Segmenty poziome fasad i rimów
var facade_segments: Array = []
