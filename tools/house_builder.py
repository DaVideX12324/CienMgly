"""Domy modułowe z Pixel Crawler Free Pack: składa PNG korpusu i dachu oraz scenę domu.

Użycie (z dowolnego katalogu):  python modules/quiz_rpg/tools/house_builder.py [preset ...]
Bez argumentów buduje wszystkie PRESETS. Wymaga Pillow, numpy, scipy.

Wyjście:
  modules/quiz_rpg/assets/textures/buildings/<id>_body.png, <id>_roof.png  (ta sama płótno i kotwica)
  modules/quiz_rpg/scenes/objects/buildings/<id>.tscn                      (StaticBody2D: kolizja, drzwi)

Zasady składania (z przykładów autora paczki):
- Dach jest modułowy: płaty dwuspadowego dachu poszerzamy powielając środkowy wycinek, tak by zachować
  nachylenie (wycinek 16 px, przesunięcie w dół o slope*16 px na każde powielenie).
- Ściana to wiersze bali między słupkami, przycięta do obrysu dachu (widać tylko szczyt między płatami).
- Okap (eave) = wysokość ściany pod końcami płatów dachu; ma sięgać górnej krawędzi drzwi.
- Origin sceny = środek dolnej krawędzi ściany (y-sort jak obiekty jaskiń); korpus i dach to dwa Sprite2D
  w tym samym punkcie, więc dach da się osobno ukryć.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.normpath(os.path.join(HERE, ".."))
HOST = os.path.normpath(os.path.join(MODULE, "..", ".."))
PACK = os.path.join(HOST, "assets", "pixel_crawler", "packs", "free_pack_2.11", "Pixel Crawler - Free Pack",
                    "Environment", "Structures", "Buildings")
TEX_DIR = os.path.join(MODULE, "assets", "textures", "buildings")
SCENE_DIR = os.path.join(MODULE, "scenes", "objects", "buildings")
TEX_RES = "res://modules/quiz_rpg/assets/textures/buildings/"

# Parametry presetów: extra = o ile px poszerzyć dach z każdej strony (wielokrotność 16), eave = wysokość okapu.
PRESETS = {
    "chata_mala": {"extra": 16, "eave": 56, "roof": "brown"},
    "chata_duza": {"extra": 48, "eave": 56, "roof": "brown"},
    "chata_zielona": {"extra": 32, "eave": 56, "roof": "teal"},
    "chata_zielona_mala": {"extra": 16, "eave": 56, "roof": "teal", "door": "right"},
    "chata_zielona_duza": {"extra": 64, "eave": 56, "roof": "teal", "door": "right"},
    "chata_brazowa_prawa": {"extra": 32, "eave": 56, "roof": "brown", "door": "right"},
    "chata_wysoka": {"extra": 32, "eave": 72, "roof": "brown"},
    "chata_wysoka_zielona": {"extra": 48, "eave": 72, "roof": "teal", "door": "right"},
    "dom_dlugi": {"extra": 80, "eave": 64, "roof": "brown"},
}

# Gdzie leży dach "B" (stromy dwuspad) w Roofs.png: (x, y, szer., wys., ziarno kalenicy, wycięcia).
ROOF_B = {
    "brown": (16, 80, 96, 96, (64, 100), [(48, 144, 32, 16), (32, 160, 64, 16)]),
    "teal": (144, 80, 96, 96, (191, 100), [(160, 160, 64, 16)]),
}
ROOF_SLOPE = 1.0
SLICE = 16
SHADOW_NEAR, SHADOW_FAR = 8, 6     # grubość ciemnego i jaśniejszego pasma cienia pod dachem (px)


def _load(name):
    return Image.open(os.path.join(PACK, name)).convert("RGBA")


W, R, P = _load("Walls.png"), _load("Roofs.png"), _load("Props.png")


def _cut(im, x, y, w, h):
    return im.crop((x, y, x + w, y + h)).copy()


def _tight(im):
    return im.crop(im.getbbox())


def _label(im):
    return nd.label(np.array(im)[:, :, 3] > 0, structure=np.ones((3, 3)))[0]


def _comp_cut(im, lab, x, y, w, h, seed, erase=()):
    """Wycinek tylko ze składowej spójnej ziarna (odcina sąsiednie elementy arkusza)."""
    a = np.array(_cut(im, x, y, w, h))
    a[~(lab == lab[seed[1], seed[0]])[y:y + h, x:x + w], 3] = 0
    for ex, ey, ew, eh in erase:
        a[max(0, ey - y):max(0, ey - y + eh), max(0, ex - x):max(0, ex - x + ew), 3] = 0
    return Image.fromarray(a)


_LAB_R, _LAB_P = _label(R), _label(P)
LOG_TILE = _cut(W, 8, 192, 16, 8)              # 16 px środka wiersza bali
POST_L, POST_R = _cut(W, 16, 128, 8, 8), _cut(W, 72, 128, 8, 8)   # słupek: okrągłe końce bali
GREY_WIN = _tight(_cut(P, 32, 80, 16, 16))
DOOR = _tight(_comp_cut(P, _LAB_P, 32, 20, 32, 56, (48, 40)))     # framuga łukowa ze schodkiem
WIN_MESH = _tight(_cut(P, 101, 100, 22, 22))
WIN_SHUT = _tight(_cut(P, 69, 96, 24, 32))


def widen(img, e):
    """Poszerza dach o e px z każdej strony, powielając wycinek płata (zachowuje nachylenie)."""
    a = np.array(img)
    al = a[:, :, 3] > 0
    tops = [int(np.argmax(al[:, c])) if al[:, c].any() else 10 ** 6 for c in range(a.shape[1])]
    m = min(tops)
    ridge = [c for c, t in enumerate(tops) if t == m]
    r0, r1 = ridge[0], ridge[-1]
    h, w = a.shape[:2]
    out = np.zeros((h + int(ROOF_SLOPE * e) + 4, w + 2 * e, 4), np.uint8)

    def put(src, dst, dy):
        for y in np.nonzero(a[:, src, 3])[0]:
            out[y + dy, dst] = a[y, src]

    for c in range(r0, r1 + 1):
        put(c, e + c, 0)
    t0 = SLICE
    for side in (-1, 1):
        n = (r0 if side < 0 else w - 1 - r1) + e
        for T in range(n):
            if T < t0:
                t, dy = T, 0
            elif T < t0 + e + SLICE:
                t = t0 + (T - t0) % SLICE
                dy = int(round(ROOF_SLOPE * (T - t)))
            else:
                t, dy = T - e, int(round(ROOF_SLOPE * e))
            if side < 0:
                c, x = r0 - 1 - t, e + r0 - 1 - T
            else:
                c, x = r1 + 1 + t, e + r1 + 1 + T
            if 0 <= c < w and 0 <= x < out.shape[1]:
                put(c, x, dy)
    return _tight(Image.fromarray(out))


def _wall_body(wb, hb):
    img = Image.new("RGBA", (wb, hb), (0, 0, 0, 0))
    for r in range(hb // 8):
        y = hb - 8 - r * 8
        for x in range(8, wb - 8, 16):
            img.alpha_composite(LOG_TILE.crop((0, 0, min(16, wb - 8 - x), 8)), (x, y))
        img.alpha_composite(POST_L, (0, y))
        img.alpha_composite(POST_R, (wb - 8, y))
    return img


def build(spec):
    """Zwraca (korpus, dach, kotwica (x, y), x drzwi względem kotwicy, szerokość ściany) na wspólnym płótnie."""
    x, y, w, h, seed, erase = ROOF_B[spec["roof"]]
    roof = widen(_tight(_comp_cut(R, _LAB_R, x, y, w, h, seed, erase)), spec["extra"])
    wb = roof.width - 16
    eave = spec["eave"]
    hb = ((roof.height + eave) // 8 + 1) * 8
    cw, ch = roof.width + 8, hb + roof.height + 8
    base = ch - 4
    bx, rx, ry = (cw - wb) // 2, (cw - roof.width) // 2, base - eave - roof.height
    wall = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    wall.alpha_composite(_wall_body(wb, hb), (bx, base - hb))
    # ściana widoczna tylko pod górną krawędzią dachu
    wa, ra = np.array(wall), np.array(roof)[:, :, 3] > 0
    for col in range(cw):
        rc = col - rx
        if 0 <= rc < roof.width and ra[:, rc].any():
            wa[:ry + int(np.argmax(ra[:, rc])), col, 3] = 0
        else:
            wa[:, col, 3] = 0
    wall = Image.fromarray(wa)
    mid = bx + wb // 2
    gable_y = ry + int(roof.height * 0.55)
    for dx in (-18, 6):
        wall.alpha_composite(GREY_WIN, (mid + dx, gable_y))
    right = spec.get("door") == "right"                         # drzwi po prawej, okiennice po lewej
    door_x = bx + wb - 16 - DOOR.width if right else bx + 16
    wall.alpha_composite(DOOR, (door_x, base - DOOR.height))
    shut_x = bx + 20 if right else bx + wb - 44
    mesh_x = mid - 4 - WIN_MESH.width if right else mid + 4
    ok = mesh_x >= shut_x + WIN_SHUT.width + 6 if right else mesh_x + WIN_MESH.width + 6 <= shut_x
    if ok:                                                      # okno z kratą tylko, gdy nie nachodzi na okiennice
        wall.alpha_composite(WIN_MESH, (mesh_x, base - eave + 8))
    wall.alpha_composite(WIN_SHUT, (shut_x, base - eave + 4))
    wa = np.array(wall).astype(float)
    for col in range(cw):                                       # cień dachu: pasma pod dolną krawędzią płatów
        rc = col - rx
        if 0 <= rc < roof.width and ra[:, rc].any():
            bottom = ry + int(np.nonzero(ra[:, rc])[0].max()) + 1
            for (d0, d1), k in (((0, SHADOW_NEAR), 0.5), ((SHADOW_NEAR, SHADOW_NEAR + SHADOW_FAR), 0.75)):
                wa[bottom + d0:bottom + d1, col, :3] *= k
    body = Image.fromarray(wa.astype(np.uint8))
    roof_layer = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    roof_layer.alpha_composite(roof, (rx, ry))
    box = body.getbbox()
    rbox = roof_layer.getbbox()
    union = (min(box[0], rbox[0]), min(box[1], rbox[1]), max(box[2], rbox[2]), max(box[3], rbox[3]))
    anchor = (mid - union[0], base - union[1])
    door_cx = door_x + DOOR.width // 2 - mid
    return body.crop(union), roof_layer.crop(union), anchor, door_cx, wb


def scene_text(name, body_size, anchor, door_cx, wb):
    ax, ay = anchor
    title = "".join(p.capitalize() for p in name.split("_"))
    return f'''[gd_scene load_steps=5 format=3]

[ext_resource type="Texture2D" path="{TEX_RES}{name}_body.png" id="1_body"]
[ext_resource type="Texture2D" path="{TEX_RES}{name}_roof.png" id="2_roof"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_base"]
size = Vector2({wb}, 16)

[sub_resource type="CircleShape2D" id="CircleShape2D_door"]
radius = 14.0

[node name="{title}" type="StaticBody2D"]
collision_layer = 32
collision_mask = 0

[node name="Body" type="Sprite2D" parent="."]
texture = ExtResource("1_body")
centered = false
offset = Vector2({-ax}, {-ay})

[node name="Roof" type="Sprite2D" parent="."]
texture = ExtResource("2_roof")
centered = false
offset = Vector2({-ax}, {-ay})

[node name="BaseCollision" type="CollisionShape2D" parent="."]
position = Vector2(0, -8)
shape = SubResource("RectangleShape2D_base")

[node name="DoorArea" type="Area2D" parent="."]
position = Vector2({door_cx}, 8)
collision_layer = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="DoorArea"]
shape = SubResource("CircleShape2D_door")

[node name="DoorSpot" type="Marker2D" parent="."]
position = Vector2({door_cx}, 12)
'''


def main(names):
    os.makedirs(TEX_DIR, exist_ok=True)
    os.makedirs(SCENE_DIR, exist_ok=True)
    for name in names or PRESETS:
        body, roof, anchor, door_cx, wb = build(PRESETS[name])
        body.save(os.path.join(TEX_DIR, name + "_body.png"))
        roof.save(os.path.join(TEX_DIR, name + "_roof.png"))
        with open(os.path.join(SCENE_DIR, name + ".tscn"), "w", newline="\n") as f:
            f.write(scene_text(name, body.size, anchor, door_cx, wb))
        print(name, body.size, "kotwica", anchor, "drzwi dx", door_cx)


if __name__ == "__main__":
    main(sys.argv[1:])
