"""Domy dwuspadowe składane z kafli (Walls / Roofs / Props z pixel_crawler_free.tres), parametrycznie.

Użycie:  python modules/quiz_rpg/tools/house_tiles.py [nazwa ...]      (bez argumentów: wszystkie HOUSES)
Wyjście: scenes/objects/buildings/<nazwa>.tscn  (StaticBody2D: warstwy kafli, kolizja, DoorArea, DoorSpot).

Reguły (z ręcznie zbudowanego dom_l_lewy):
- Dach A to próbka 8x6 kafli (Roofs 0..7 x 0..5): kolumny 3,4 = kalenica, 1,2 / 5,6 = para płata, 0 / 7 = krańce.
  Szerokość: n kolejnych par z każdej strony, każda para o wiersz niżej (spadek 1:2) -> dach ma 8 + 4n kolumn,
  ściana W = 4 + 4n. Głębokość: d dodatkowych wierszy wypełnienia (wiersz 3) w każdej kolumnie.
- Ściana to pasy 1x3 kafle (tileset: size_in_atlas 1x3): dolny pas (x,8) z kotwicą w wierszu B, wyższe pasy (x,12) co 3 wiersze;
  zestawy materiałów: przesunięcie kolumn o 6 (0 kłody, 1 deski poziome, 2 deski pionowe, 3 tynk). Pas nie może wystawać nad dach.
- Fasada: drzwi 2 kolumny w środku (rama Props 2..3 x 1..4, skrzydło 8..9 x 1..3), okna łukowe Props (6..7, 4..5) co 2 kolumny,
  okna szczytowe Props (8..9, 6..7). Teal = kafle dachu +8 kolumn atlasu.
"""
import base64
import os
import random
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.normpath(os.path.join(HERE, "..", "scenes", "objects", "buildings"))
WALLS, ROOFS, PROPS = 5, 6, 7

# n = liczba dodatkowych par płata z każdej strony (W = 4 + 4n), d = dodatkowe wiersze wypełnienia dachu,
# e = widoczne wiersze ściany pod okapem (6 = jak dom_l_lewy), kit = materiał ściany, teal = turkusowy dach, chimney = komin.
HOUSES = {
    "dom_k_chata_8": {"n": 1, "d": 1, "e": 6, "kit": 0, "teal": False, "chimney": False},
    "dom_k_chata_12": {"n": 2, "d": 3, "e": 6, "kit": 0, "teal": False, "chimney": True},
    "dom_k_dluga_16": {"n": 3, "d": 2, "e": 6, "kit": 0, "teal": True, "chimney": True},
    "dom_k_deski_12": {"n": 2, "d": 2, "e": 6, "kit": 1, "teal": True, "chimney": False},
    "dom_k_pionowe_8": {"n": 1, "d": 2, "e": 6, "kit": 2, "teal": False, "chimney": True},
    "dom_k_tynk_12": {"n": 2, "d": 3, "e": 6, "kit": 3, "teal": False, "chimney": True},
    "dom_k_wysoki_8": {"n": 1, "d": 3, "e": 9, "kit": 0, "teal": True, "chimney": False},
}

# próbka dachu: kolumna -> (pierwszy wiersz, ostatni wiersz) w arkuszu Roofs
SAMPLE = {0: (2, 5), 1: (1, 5), 2: (1, 4), 3: (0, 5), 4: (0, 5), 5: (1, 4), 6: (1, 5), 7: (2, 5)}
FILL_ROW = 3


def roof_cells(n, d, x0, r0):
    """Komórki dachu {(x, y): (ax, ay)}; x0 = kolumna lewej połówki kalenicy, r0 = wiersz szczytu kalenicy."""
    cells = {}

    def put(col, x, shift):
        top, bot = SAMPLE[col]
        y = r0 + shift
        for ay in range(top, bot + 1):
            cells[(x, y + ay)] = (col, ay)
            if ay == FILL_ROW:
                for _ in range(d):
                    y += 1
                    cells[(x, y + ay)] = (col, FILL_ROW)

    put(3, x0, 0)
    put(4, x0 + 1, 0)
    for k in range(n + 1):
        put(2, x0 - 1 - 2 * k, k)
        put(1, x0 - 2 - 2 * k, k)
        put(5, x0 + 2 + 2 * k, k)
        put(6, x0 + 3 + 2 * k, k)
    put(0, x0 - 3 - 2 * n, n)
    put(7, x0 + 4 + 2 * n, n)
    return cells


def build(spec, rnd):
    n, dd, e, kit = spec["n"], spec["d"], spec["e"], spec["kit"]
    W = 4 + 4 * n
    B, xl = 0, 0                # wiersz dolnego pasa ściany, lewa kolumna ściany
    x0 = xl + W // 2 - 1        # lewa połowa kalenicy
    rb = B - e                  # dolny wiersz dachu w kolumnie kalenicy
    r0 = rb - 5 - dd
    roof = roof_cells(n, dd, x0, r0)
    top = {}
    for (x, y) in roof:
        top[x] = min(top.get(x, 10 ** 6), y)
    K = 6 * kit
    walls = []
    for x in range(xl, xl + W):
        left, right = x == xl, x == xl + W - 1
        walls.append((x, B + 1, WALLS, K + (1 if left else 3 if right else 2), 49))      # cień pod ścianą
        for k in range(9):
            row = B - 3 * k
            if k > 0 and row - 2 < top.get(x, 10 ** 6) + 1:
                break
            if k == 0:
                tile = (K + (1 if left else 4 if right else 2), 8)
            else:
                tile = (K + (0 if left else 5 if right else rnd.choice((1, 2))), 12)
            walls.append((x, row, WALLS, *tile))
    xd = xl + W // 2 - 1        # lewa kolumna drzwi
    frame = [(xd + i, B - 2 + j, PROPS, 2 + i, 1 + j) for i in (0, 1) for j in range(4)]
    props = [(xd + i, B - 2 + j, PROPS, 8 + i, 1 + j) for i in (0, 1) for j in range(3)]    # skrzydło drzwi
    for o in range(2, W // 2, 2):                                                         # okna łukowe symetrycznie od drzwi
        lx, rx = xd - o, xd + 1 + o - 1
        if lx > xl and rx + 1 < xl + W - 1:
            for bx in (lx, rx):
                props += [(bx + i, B - 2 + j, PROPS, 6 + i, 4 + j) for i in (0, 1) for j in (0, 1)]
    for gx in (x0 - 2, x0 + 3):                                                           # okna szczytowe pod kalenicą
        props += [(gx + i, rb + 1 + j, PROPS, 8 + i, 6 + j) for i in (0, 1) for j in (0, 1)]
    return W, B, xl, x0, r0, roof, walls, frame, props


def pack(cells):
    body = b"\x00\x00" + b"".join(struct.pack("<hhHHHH", x, y, src, ax, ay, 0) for x, y, src, ax, ay in cells)
    return base64.b64encode(body).decode()


def layer(name, ox, oy, cells, ysort=True, z=0, parent="."):
    head = '[node name="%s" type="TileMapLayer" parent="%s"]\n' % (name, parent)
    if parent == ".":
        head += "position = Vector2(%d, %d)\n" % (ox, oy)
    if z:
        head += "z_index = %d\n" % z
    if ysort:
        head += "y_sort_enabled = true\n"
    return head + 'tile_map_data = PackedByteArray("%s")\ntile_set = ExtResource("1_tiles")\n\n' % pack(cells)


def scene(name, spec):
    rnd = random.Random(name)
    W, B, xl, x0, r0, roof, walls, frame, props = build(spec, rnd)
    xd = xl + W // 2 - 1
    ox, oy = -(xd + 1) * 16, -(B + 1) * 16          # origin: środek drzwi na dolnej krawędzi ściany (wiersz B)
    shift = 8 if spec["teal"] else 0
    roof_t = [(x, y, ROOFS, ax + shift, ay) for (x, y), (ax, ay) in sorted(roof.items())]
    layers = (layer("Walls", ox, oy, walls) + layer("Roof", ox, oy, roof_t, ysort=False) +
              layer("DoorFrame", ox, oy, frame) + layer("Props", ox, oy, props))
    if spec["chimney"] and spec["n"] >= 1:
        cx, cy = x0 - 4, r0 + 2
        chim = [(cx + i, cy + j, PROPS, i, 4 + j) for i in (0, 1) for j in range(4)]
        cap = [(cx + i, cy + 3 + j, ROOFS, 1 + i + shift, 1 + j) for i in (0, 1) for j in (0, 1)]
        layers += layer("Chimney", ox, oy, chim, z=1) + layer("ChimneyRoof", 0, 0, cap, ysort=False, parent="Chimney")
    title = "".join(p.capitalize() for p in name.split("_"))
    return ('[gd_scene format=4]\n\n'
            '[ext_resource type="TileSet" uid="uid://c273qhq1dnqgr" path="res://modules/quiz_rpg/resources/maps/pixel_crawler_free.tres" id="1_tiles"]\n\n'
            '[sub_resource type="RectangleShape2D" id="Rect_base"]\nsize = Vector2(%d, 16)\n\n'
            '[sub_resource type="CircleShape2D" id="Circle_door"]\nradius = 14.0\n\n'
            '[node name="%s" type="StaticBody2D"]\ny_sort_enabled = true\ncollision_layer = 32\ncollision_mask = 0\n\n%s'
            '[node name="BaseCollision" type="CollisionShape2D" parent="."]\nposition = Vector2(0, -8)\nshape = SubResource("Rect_base")\n\n'
            '[node name="DoorArea" type="Area2D" parent="."]\nposition = Vector2(0, 8)\ncollision_layer = 0\n\n'
            '[node name="CollisionShape2D" type="CollisionShape2D" parent="DoorArea"]\nshape = SubResource("Circle_door")\n\n'
            '[node name="DoorSpot" type="Marker2D" parent="."]\nposition = Vector2(0, 24)\n') % (W * 16, title, layers)


def main(names):
    for name in names or HOUSES:
        with open(os.path.join(DIR, name + ".tscn"), "w", encoding="utf8", newline="\n") as f:
            f.write(scene(name, HOUSES[name]))
        print(name)


if __name__ == "__main__":
    main(sys.argv[1:])
