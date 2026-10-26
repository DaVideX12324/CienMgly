#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cienie obiektów w stylu Pixel Crawlera (Props/Static/Shadows.png: czarny, alfa 39, jeden odcień).

Cień = sylwetka sprite'ów sceny ściśnięta w pionie do SQUASH * szerokości (jak cienie koron
z paczki: 105x48 przy drzewie szerokim na 106 px), z wypełnionymi dziurami, środkiem w podstawie
obiektu (dół sprite'a - 2 px = origin). Wszystkie cienie trafiają do jednego atlasu PNG,
a każda scena dostaje na końcu węzeł "Shadow" (Sprite2D, z_index 0, show_behind_parent -> pod sprite'ami
obiektu, w y-sorcie razem z nim).

Duże drzewa (ROTATED: rozmiary s3-s5): cień obrócony o 180° i przesunięty pod drzewo — górna krawędź
w podstawie, korona cienia pada na południe (wzór usera: tree_m3_s3_r0c0 / r1c0).

Ponowne uruchomienie przelicza atlas i podmienia region / offset istniejących węzłów "Shadow";
position / rotation już obecne w węźle zostają (ręczne poprawki usera).

Użycie (z katalogu hosta):
    python modules/quiz_rpg/tools/object_shadows.py [--dry-run]
"""

import argparse
import glob
import os
import re
import sys

from PIL import Image

HOST = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SCENES = "modules/quiz_rpg/scenes/objects/pixel_crawler"
ATLAS = ("assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/Environment/Props/Static/"
         "Shadows_Objects.png")
SHADOW = (0, 0, 0, 39)
SQUASH = 0.45
ATLAS_W = 512
PAD = 1
BASE_LIFT = 2  # dół sprite'a leży 2 px pod origin (środek kratki kotwicy)
# sceny bez cienia (wisząca lampa) albo dziedziczące cień po bazie
SKIP = {"lamps/lantern_hanging.tscn", "lamps/lamp_post.tscn", "lamps/lamp_post_left.tscn"}
ROTATED = re.compile(r"^trees/tree_m\d_s[345]_")
TEX_ID = "shadow_tex"
SUB_ID = "AtlasTexture_shadow"


def res_to_fs(path):
    return os.path.join(HOST, path.replace("res://", ""))


def sections(text):
    out = []
    for m in re.finditer(r"^\[(\w+)([^\n]*)\]$", text, re.M):
        attrs = {k: v.strip('"') for k, v in re.findall(r'(\w+)=("[^"]*"|\S+)', m.group(2))}
        end = text.find("\n[", m.end())
        body = text[m.end():end if end >= 0 else len(text)]
        props = dict(re.findall(r"^(\w[\w/]*) = (.*)$", body, re.M))
        out.append({"kind": m.group(1), "attrs": attrs, "props": props})
    return out


def vec2(s, default=(0.0, 0.0)):
    if not s:
        return default
    m = re.match(r"Vector2\(([-\d.e]+), ([-\d.e]+)\)", s)
    return float(m.group(1)), float(m.group(2))


def ref(s):
    m = re.search(r'(?:Sub|Ext)Resource\("([^"]+)"\)', s or "")
    return m.group(1) if m else None


def silhouette(text):
    """Maska alfa sprite'ów korzenia (bez zagnieżdżonych, bez ukrytych) w układzie sceny."""
    S = sections(text)
    ext = {s["attrs"]["id"]: s["attrs"]["path"] for s in S if s["kind"] == "ext_resource"}
    sub = {s["attrs"]["id"]: s for s in S if s["kind"] == "sub_resource"}
    parts = []
    for n in S:
        if n["kind"] != "node" or n["attrs"].get("type") != "Sprite2D" or n["attrs"].get("parent") != ".":
            continue
        if n["attrs"].get("name") == "Shadow" or n["props"].get("visible") == "false":
            continue
        tid = ref(n["props"].get("texture"))
        if tid in sub:
            at = sub[tid]["props"]
            img = Image.open(res_to_fs(ext[ref(at["atlas"])])).convert("RGBA")
            x, y, w, h = (int(float(v)) for v in re.findall(r"[-\d.]+", at["region"].split("(", 1)[1]))
            img = img.crop((x, y, x + w, y + h))
        elif tid in ext:
            img = Image.open(res_to_fs(ext[tid])).convert("RGBA")
        else:
            continue
        if n["props"].get("flip_h") == "true":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        px, py = vec2(n["props"].get("position"))
        ox, oy = vec2(n["props"].get("offset"))
        if n["props"].get("centered", "true") == "true":
            ox -= img.width / 2
            oy -= img.height / 2
        parts.append((img, int(round(px + ox)), int(round(py + oy))))
    if not parts:
        return None
    x0 = min(p[1] for p in parts)
    y0 = min(p[2] for p in parts)
    x1 = max(p[1] + p[0].width for p in parts)
    y1 = max(p[2] + p[0].height for p in parts)
    mask = [[False] * (x1 - x0) for _ in range(y1 - y0)]
    for img, ox, oy in parts:
        a = img.getchannel("A").load()
        for yy in range(img.height):
            for xx in range(img.width):
                if a[xx, yy] > 0:
                    mask[oy - y0 + yy][ox - x0 + xx] = True
    return mask, x0, y1


def crop_mask(mask):
    rows = [i for i, r in enumerate(mask) if any(r)]
    cols = [j for j in range(len(mask[0])) if any(r[j] for r in mask)]
    return [r[cols[0]:cols[-1] + 1] for r in mask[rows[0]:rows[-1] + 1]], cols[0], rows[-1] + 1


def fill_holes(mask):
    h, w = len(mask), len(mask[0])
    outside = [[False] * w for _ in range(h)]
    st = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while st:
        x, y = st.pop()
        if 0 <= x < w and 0 <= y < h and not outside[y][x] and not mask[y][x]:
            outside[y][x] = True
            st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return [[not outside[y][x] for x in range(w)] for y in range(h)]


def turned(img, off):
    """position węzła cienia obróconego o 180°: górna krawędź w podstawie (y = 0), ten sam zakres x."""
    return 2 * off[0] + img.width, off[1] + img.height


def shadow_of(text):
    """(obraz cienia, offset względem origin) albo None."""
    s = silhouette(text)
    if s is None:
        return None
    mask, x0, bottom = s
    mask, dx, dy_bottom = crop_mask(mask)
    x0 += dx
    bottom = bottom - (len(s[0]) - dy_bottom)  # dół niepustej sylwetki w układzie sceny
    h, w = len(mask), len(mask[0])
    sh = max(2, min(h, int(round(SQUASH * w))))
    out = []
    for r in range(sh):
        a, b = r * h // sh, max(r * h // sh + 1, (r + 1) * h // sh)
        out.append([any(mask[k][c] for k in range(a, b)) for c in range(w)])
    out = fill_holes(out)
    img = Image.new("RGBA", (w, sh), (0, 0, 0, 0))
    for y in range(sh):
        for x in range(w):
            if out[y][x]:
                img.putpixel((x, y), SHADOW)
    base_y = bottom - BASE_LIFT
    return img, (x0, base_y - sh // 2)


def pack(images):
    """Półkowe pakowanie: klucz -> (x, y). Obrazy posortowane malejąco po wysokości."""
    pos = {}
    x = y = row_h = 0
    for key, img in sorted(images.items(), key=lambda kv: (-kv[1].height, -kv[1].width)):
        if x + img.width > ATLAS_W:
            x, y, row_h = 0, y + row_h + PAD, 0
        pos[key] = (x, y)
        x += img.width + PAD
        row_h = max(row_h, img.height)
    return pos, y + row_h


SHADOW_NODE = r'\[node name="Shadow" type="Sprite2D" parent="\."[^\]\n]*\]\n'
BEHIND = "show_behind_parent = true\n"


def patch_scene(text, region, offset, turn=None):
    """turn: position cienia obróconego o 180° (duże drzewa) albo None. Istniejących position/rotation
    węzła nie rusza."""
    reg = "Rect2(%d, %d, %d, %d)" % region
    off = "Vector2(%d, %d)" % offset
    rot = "position = Vector2(%d, %d)\nrotation = 3.1415927\n" % turn if turn else ""
    if SUB_ID in text:
        text = re.sub(r'(\[sub_resource type="AtlasTexture" id="%s"\]\n(?:.*\n)*?region = )Rect2\([^)]*\)' % SUB_ID,
                      lambda m: m.group(1) + reg, text, count=1)
        text = re.sub(r"(%s(?:.*\n)*?offset = )Vector2\([^)]*\)" % SHADOW_NODE,
                      lambda m: m.group(1) + off, text, count=1)
        node = re.search(SHADOW_NODE + r"(?:[^\[\n].*\n?)*", text)
        body = node.group(0)
        if "show_behind_parent = " not in body:
            body = re.sub(SHADOW_NODE, lambda m: m.group(0) + BEHIND, body, count=1)
        if rot and "rotation = " not in body and "position = " not in body:
            body = body.replace(BEHIND, BEHIND + rot, 1)
        return text[:node.start()] + body + text[node.end():]
    ext_line = '[ext_resource type="Texture2D" path="res://%s" id="%s"]' % (ATLAS, TEX_ID)
    sub = ('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = %s\nfilter_clip = true\n\n'
           % (SUB_ID, TEX_ID, reg))
    node = ('\n[node name="Shadow" type="Sprite2D" parent="."]\n%s%stexture = SubResource("%s")\n'
            'centered = false\noffset = %s\n' % (BEHIND, rot, SUB_ID, off))
    exts = list(re.finditer(r"^\[ext_resource [^\n]*\]$", text, re.M))
    text = text[:exts[-1].end()] + "\n" + ext_line + text[exts[-1].end():]
    first_node = re.search(r"^\[node ", text, re.M)
    text = text[:first_node.start()] + sub + text[first_node.start():]
    return text.rstrip("\n") + "\n" + node


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    root = os.path.join(HOST, SCENES)
    shadows, per_scene = {}, {}
    for f in sorted(glob.glob(os.path.join(root, "**", "*.tscn"), recursive=True)):
        rel = os.path.relpath(f, root).replace("\\", "/")
        if rel in SKIP:
            continue
        text = open(f, encoding="utf-8", newline="").read()
        res = shadow_of(text)
        if res is None:
            print("bez sprite'a:", rel)
            continue
        img, off = res
        key = img.tobytes() + bytes(str(img.size), "ascii")
        shadows.setdefault(key, img)
        per_scene[f] = (key, off, turned(img, off) if ROTATED.match(rel) else None)
    pos, h = pack(shadows)
    atlas = Image.new("RGBA", (ATLAS_W, h), (0, 0, 0, 0))
    for key, img in shadows.items():
        atlas.paste(img, pos[key])
    print("scen: %d, różnych cieni: %d, atlas %dx%d" % (len(per_scene), len(shadows), ATLAS_W, h))
    if args.dry_run:
        atlas.save(os.path.join(os.environ.get("TEMP", "."), "Shadows_Objects_dry.png"))
        return
    atlas.save(os.path.join(HOST, ATLAS))
    for f, (key, off, turn) in per_scene.items():
        img = shadows[key]
        text = open(f, encoding="utf-8", newline="").read()
        new = patch_scene(text, (pos[key][0], pos[key][1], img.width, img.height), off, turn)
        if new != text:
            open(f, "w", encoding="utf-8", newline="").write(new)


if __name__ == "__main__":
    sys.exit(main())
