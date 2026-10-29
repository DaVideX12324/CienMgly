"""Sceny obiektów z atlasu ruin (gen_ruins_atlas.py) i zamienników Desert Oasis wziętych wprost z plików Pixel Crawlera:
StaticBody2D (warstwa 32) + Sprite2D z AtlasTexture (punkt sceny = środek podstawy sprite'a) + kolizja przy podstawie
(drobiazgi bez kolizji). Ruiny -> scenes/objects/pixel_crawler/ruins/, miejskie -> scenes/objects/pixel_crawler/props/.
Uruchomienie: python -I gen_ruins_scenes.py (po gen_ruins_atlas.py; istniejące sceny są nadpisywane)."""
import os
import re

from PIL import Image

import gen_ruins_atlas as gra

MOD = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OBJ = os.path.join(MOD, "scenes/objects/pixel_crawler")
RES_ASSETS = "res://assets/"
SEWER_TILES = "pixel_crawler/environments/sewer/Assets/Tiles.png"
CEMETERY = "pixel_crawler/environments/cemetery/Pixel Crawler - Cemetery/Environment/Props/"
HIDEOUT_TILES = "pixel_crawler/environments/hideout/Pixel Crawler - Hideout/Assets/Tiles.png"
STATIC = "pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/Environment/Props/Static/"
RUINS = STATIC + "Ruins.png"

TOWN = {"drogowskaz", "tablica_menu", "tablica_ogloszen", "bal", "bale_stos", "szczatki"}
FLIPPED = {"szczatki_odbite": "szczatki"}   # odbicie w scenie (flip_h), bez kopii w atlasie
NO_COLLISION = ("odlamki", "szczatki", "lopata", "deska", "dzban_rozbity")
LYING = ("lezac", "bal", "mur", "przewrocon", "pekniety", "stos")
# elementy bez zmian prosto z plików widocznych w Godocie: nazwa -> (plik w assets/, obszar do przycięcia, flip_h)
EXTERNAL = {
    "sciek_filar": (SEWER_TILES, (192, 48, 208, 120), False),
    "sciek_filar_ulamany": (SEWER_TILES, (208, 48, 224, 120), False),
    "sciek_filar_kikut": (SEWER_TILES, (224, 48, 240, 120), False),
    "deska_ukos": (STATIC + "Furniture.png", (146, 561, 174, 590), False),
    "deska_ukos_2": (STATIC + "Furniture.png", (82, 593, 111, 622), False),
    "deska": (STATIC + "Furniture.png", (112, 565, 144, 571), False),
    "worek": (STATIC + "Farm.png", (256, 2, 272, 14), False),
    "lopata": (CEMETERY + "Props.png", (82, 49, 93, 80), False),
    "lopata_kopiec": (CEMETERY + "Props.png", (128, 48, 159, 80), False),
    "cmentarz_nagrobek_rozbity_1": (CEMETERY + "Graves.png", (0, 64, 16, 96), False),
    "cmentarz_nagrobek_rozbity_2": (CEMETERY + "Graves.png", (16, 64, 32, 96), False),
    "cmentarz_nagrobek_rozbity_3": (CEMETERY + "Graves.png", (32, 64, 48, 96), False),
    "skrzynia": (HIDEOUT_TILES, (224, 272, 256, 304), False),
    "skrzynia_otwarta": (HIDEOUT_TILES, (256, 260, 288, 304), False),
    "worek_pelny": (STATIC + "Farm.png", (256, 16, 271, 32), False),
}
EXTERNAL_TOWN = {"lopata", "lopata_kopiec", "skrzynia", "skrzynia_otwarta", "deska_ukos", "deska_ukos_2", "deska", "worek", "worek_pelny"}


def uid_of(rel):
    imp = os.path.join(gra.A, rel + ".import")
    m = re.search(r'^uid="([^"]+)"', open(imp, encoding="utf-8").read(), re.M) if os.path.exists(imp) else None
    return m.group(1) if m else None


def node_name(name):
    return "".join(part.capitalize() for part in name.split("_"))


def collision(name, w, h):
    if any(k in name for k in NO_COLLISION):
        return None
    if any(k in name for k in LYING):
        hw, top = max(2, w // 2 - 3), min(8, max(3, h // 3))
    else:
        hw, top = max(2, int(w * 0.32)), min(6, max(3, h // 4))
    return "PackedVector2Array(%d, %d, %d, %d, %d, %d, %d, %d)" % (-hw, -top, hw, -top, hw, 1, -hw, 1)


def scene(name, tex_rel, rect, flip=False, group="props"):
    x, y, w, h = rect
    uid = uid_of(tex_rel)
    lines = ["[gd_scene format=3]", "",
             '[ext_resource type="Texture2D"%s path="%s%s" id="1_tex"]' % (' uid="%s"' % uid if uid else "", RES_ASSETS, tex_rel), "",
             '[sub_resource type="AtlasTexture" id="AtlasTexture_main"]', 'atlas = ExtResource("1_tex")',
             "region = Rect2(%d, %d, %d, %d)" % (x, y, w, h), "filter_clip = true", ""]
    lines += ['[node name="%s" type="StaticBody2D"]' % node_name(name), "collision_layer = 32", "collision_mask = 0",
              'metadata/object_group = "%s"' % group, "",
              '[node name="Sprite2D" type="Sprite2D" parent="."]', 'texture = SubResource("AtlasTexture_main")', "centered = false"]
    if flip:
        lines.append("flip_h = true")
    lines += ["offset = Vector2(%d, %d)" % (-(w // 2), -h), ""]
    poly = collision(name, w, h)
    if poly:
        lines += ['[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="."]', "polygon = " + poly, ""]
    return "\n".join(lines)


def write(folder, name, text):
    os.makedirs(os.path.join(OBJ, folder), exist_ok=True)
    with open(os.path.join(OBJ, folder, name + ".tscn"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    placed, _ = gra.pack(gra.groups())
    n = 0
    for name, im, x, y in placed:
        town = name in TOWN
        write("props" if town else "ruins", name, scene(name, RUINS, (x, y, im.width, im.height), group="props" if town else "ruins"))
        n += 1
        for flipped, src in FLIPPED.items():
            if src == name:
                write("props" if town else "ruins", flipped, scene(flipped, RUINS, (x, y, im.width, im.height), True,
                                                                  "props" if town else "ruins"))
                n += 1
    for name, (rel, box, flip) in EXTERNAL.items():
        im = Image.open(os.path.join(gra.A, rel)).convert("RGBA").crop(box)
        bx0, by0, bx1, by1 = im.getbbox()
        town = name in EXTERNAL_TOWN
        write("props" if town else "ruins", name,
              scene(name, rel, (box[0] + bx0, box[1] + by0, bx1 - bx0, by1 - by0), flip, "props" if town else "ruins"))
        n += 1
    print("scen:", n)


if __name__ == "__main__":
    main()
