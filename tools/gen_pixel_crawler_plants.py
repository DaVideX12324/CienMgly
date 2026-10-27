"""Małe rośliny z Pixel Crawler free pack (Props/Static/Vegetation.png) -> sceny bez kolizji w scenes/objects/pixel_crawler/plants/.

Arkusz ma trzy warianty kolorystyczne (zielony, oliwkowy, rdzawy) po 3 rzędy drobnicy, fioletowe naparstnice (tylko zielony),
grzyby i cztery rzędy kwiatków (pomarańczowe, białe, niebieskie, żółte). Komponenty wycina się po łączności pikseli.
Użycie: python tools/gen_pixel_crawler_plants.py [--preview]
"""
import os, re, sys, random, string
from PIL import Image
import numpy as np
from scipy import ndimage

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
PNG = 'assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png'
OUT = ROOT + 'modules/quiz_rpg/scenes/objects/pixel_crawler/plants/'
random.seed(11)
used = set()


def uniq():
    while True:
        v = random.randint(10 ** 9, 2 ** 31 - 1)
        if v not in used:
            used.add(v)
            return v


def rid(n=5):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(n))


def tex_uid():
    t = open(ROOT + PNG + '.import').read()
    return re.search(r'uid="(uid://[^"]+)"', t).group(1)


def components(a, x0, y0, x1, y1, grow=0, cut=0):
    """Komponenty 8-spójne w prostokącie: [(x, y, w, h)] posortowane rzędami.
    grow: dylatacja przed etykietowaniem (sklejanie płatków); cut: sklejone obiekty o szerokości > cut dzielone co 16 px."""
    sub = a[y0:y1, x0:x1]
    mask = ndimage.binary_dilation(sub, iterations=grow) if grow else sub
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    out = []
    for i, s in enumerate(ndimage.find_objects(lab)):
        ys, xs = s
        pieces = [(xs.start, xs.stop)]
        if cut and xs.stop - xs.start > cut and x0 + xs.start >= 108:
            c0 = (x0 + xs.start) // 16 * 16 + 16
            pieces = []
            lo = xs.start
            while c0 < x0 + xs.stop:
                pieces.append((lo, c0 - x0))
                lo = c0 - x0
                c0 += 16
            pieces.append((lo, xs.stop))
        for lo, hi in pieces:
            part = (lab[ys, lo:hi] == i + 1) & sub[ys, lo:hi]
            yy, xx = np.where(part)
            if len(yy) == 0:
                continue
            out.append((x0 + lo + int(xx.min()), y0 + ys.start + int(yy.min()),
                        int(xx.max() - xx.min() + 1), int(yy.max() - yy.min() + 1)))
    out.sort(key=lambda r: (r[1] // 8, r[0]))
    return out


def write(group, name, rect):
    x, y, w, h = rect
    u = tex_uid()
    ext = f'1_{rid()}'
    atlas = f'AtlasTexture_{rid()}'
    title = ''.join(p.capitalize() for p in name.split('_'))
    s = '[gd_scene format=3]\n\n'
    s += f'[ext_resource type="Texture2D" uid="{u}" path="res://{PNG}" id="{ext}"]\n\n'
    s += f'[sub_resource type="AtlasTexture" id="{atlas}"]\natlas = ExtResource("{ext}")\nregion = Rect2({x}, {y}, {w}, {h})\nfilter_clip = true\n\n'
    s += f'[node name="{title}" type="Node2D" unique_id={uniq()}]\nmetadata/object_group = "{group}"\n\n'
    s += f'[node name="Sprite2D" type="Sprite2D" parent="." unique_id={uniq()}]\ntexture = SubResource("{atlas}")\ncentered = false\n'
    s += f'offset = Vector2({-int(round(w / 2.0))}, {-(h - 1)})\n'
    os.makedirs(OUT, exist_ok=True)
    open(OUT + name + '.tscn', 'w', newline='\n').write(s)


def main():
    a = np.array(Image.open(ROOT + PNG).convert('RGBA'))[:, :, 3] > 0
    items = []  # (group, name, rect)
    colors = ['green', 'olive', 'rust']
    for ci, col in enumerate(colors):
        y0 = 146 + 48 * ci
        for k, r in enumerate(components(a, 0, y0, 250, y0 + 48, cut=20)):
            x, y, w, h = r
            if w * h < 16:
                continue  # pojedyncze piksele przy liściach
            if x >= 190 and y + h <= y0 + 1:
                continue
            if x >= 160 and col == 'green' and h >= 12 and x >= 190:
                grp = 'flowers'  # naparstnice
            elif x >= 160:
                grp = 'reeds'
            elif x >= 128 and w > 14:
                grp = 'reeds'
            else:
                grp = 'grass'
            items.append((grp, f'{grp}_{col}_{k:02d}', r))
    # grzyby i kwiatki (dolna część arkusza)
    for k, r in enumerate(components(a, 0, 330, 260, 362)):
        x, y, w, h = r
        if w >= 30 or (y >= 350 and h < 16):
            continue  # pasek spadłych liści
        items.append(('mushrooms', f'mushroom_{k:02d}', r))
    flower_cols = ['orange', 'white', 'blue', 'yellow']
    for ci, col in enumerate(flower_cols):
        y0 = 370 + 16 * ci
        for k, r in enumerate(components(a, 0, y0, 230, y0 + 14, grow=1)):
            x, y, w, h = r
            if w < 6 or h < 5:
                continue  # kropki i pączki
            items.append(('flowers', f'flower_{col}_{k:02d}', r))
    for grp, name, r in items:
        write(grp, name, r)
    print(len(items), 'scen w', OUT)
    if '--preview' in sys.argv:
        im = Image.open(ROOT + PNG).convert('RGBA')
        bg = Image.new('RGBA', im.size, (70, 110, 70, 255))
        bg.alpha_composite(im)
        from PIL import ImageDraw
        d = ImageDraw.Draw(bg)
        for grp, name, (x, y, w, h) in items:
            d.rectangle([x - 1, y - 1, x + w, y + h], outline=(255, 0, 255, 255))
        bg.crop((0, 138, 260, 432)).resize((1040, 1176), Image.NEAREST).save(os.path.join(os.environ.get('TEMP', '.'), 'veg_plants_preview.png'))


main()
