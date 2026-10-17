"""Warianty domu z kafli (dom_l_lewy.tscn, ręcznie zbudowany): odbicie w poziomie, zielony dach, bez komina.

Użycie:  python modules/quiz_rpg/tools/house_tile_variants.py
Źródło: scenes/objects/buildings/dom_l_lewy.tscn (zmiany usera w bazie przechodzą do wariantów po ponownym uruchomieniu).
Wyjście: dom_l_lewy_zielony, dom_l_lewy_bez_komina, dom_l_prawy, dom_l_prawy_zielony, dom_l_prawy_bez_komina (.tscn obok).

- Odbicie: komórka x -> -43 - x (oś = środek drzwi, x = -21 | -22 granica), flaga FLIP_H (1 << 12) w alternatywie.
- Zielony dach: kafle z Roofs (źródło 6) przesunięte o 8 kolumn atlasu (brązowy blok -> turkusowy).
- Bez komina: usuwa warstwę komina i jego dziecko (kafle dachu pod kominem).
"""
import base64
import os
import re
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.normpath(os.path.join(HERE, "..", "scenes", "objects", "buildings"))
FLIP_H = 1 << 12
ROOFS = 6
CHIMNEY = "TileMapLayer5"


def _cells(b64):
    b = base64.b64decode(b64)
    return [list(struct.unpack_from("<hhHHHH", b, o)) for o in range(2, len(b) - 11, 12)]


def _pack(cells):
    return base64.b64encode(b"\x00\x00" + b"".join(struct.pack("<hhHHHH", *c) for c in cells)).decode()


def make(base, mirror, teal, chimney):
    blocks = base.split("\n\n[node ")
    out = [blocks[0]]
    for blk in blocks[1:]:
        blk = "[node " + blk
        name = re.match(r'\[node name="([^"]+)"', blk).group(1)
        parent = re.search(r'parent="([^"]+)"', blk)
        if not chimney and (name == CHIMNEY or (parent and parent.group(1) == CHIMNEY)):
            continue
        m = re.search(r'tile_map_data = PackedByteArray\("([^"]+)"\)', blk)
        if m:
            cells = _cells(m.group(1))
            for c in cells:
                if teal and c[2] == ROOFS:
                    c[3] += 8
                if mirror:
                    c[0] = -43 - c[0]
                    c[5] ^= FLIP_H
            blk = blk.replace(m.group(1), _pack(cells))
        if mirror and name.startswith("BaseCollisionAnnex"):
            blk = re.sub(r"position = Vector2\((-?\d+), ", lambda k: "position = Vector2(%d, " % -int(k.group(1)), blk)
        out.append(blk)
    return "\n\n".join(out)


def main():
    path = os.path.join(DIR, "dom_l_lewy.tscn")
    raw = open(path, encoding="utf8", newline="").read()
    nl = "\r\n" if "\r\n" in raw else "\n"
    base = raw.replace(nl, "\n")
    base = re.sub(r"(\[gd_scene [^\]]*?) uid=\"[^\"]+\"", r"\1", base, count=1)
    variants = {
        "dom_l_lewy_zielony": (False, True, True),
        "dom_l_lewy_bez_komina": (False, False, False),
        "dom_l_prawy": (True, False, True),
        "dom_l_prawy_zielony": (True, True, True),
        "dom_l_prawy_bez_komina": (True, False, False),
    }
    for name, (mirror, teal, chimney) in variants.items():
        txt = make(base, mirror, teal, chimney)
        title = "".join(p.capitalize() for p in name.split("_"))
        txt = txt.replace('[node name="DomLLewy"', '[node name="%s"' % title, 1)
        with open(os.path.join(DIR, name + ".tscn"), "w", encoding="utf8", newline="\n") as f:
            f.write(txt)
        print(name)


if __name__ == "__main__":
    main()
