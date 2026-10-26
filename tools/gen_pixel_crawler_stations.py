"""Sceny obiektów ze Structures/Stations paczki Pixel Crawler Free -> scenes/objects/pixel_crawler/stations/.

Statyczne: arkusze przeglądowe (Anvil, Furnace, Workbench, Bonfire, Cooking Station + Estructure, Sawmill/Base) tną się
na obiekty wg pasm kolumn i przerw w wierszach / spójnych plam. Stoły alchemiczne (Alchemy_Table_0N-Sheet) to animacje
(AnimatedSprite2D). Origin = środek dołu - 2 px, kolizja = podstawa obiektu. Katalog JSON generatora nie jest ruszany.

Użycie: python gen_pixel_crawler_stations.py [--preview]   (--preview: tylko zrzut cięcia do %TEMP%, bez scen)
"""
import os, re, random, string, sys
from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
PACK = 'assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/Environment/Structures/Stations/'
OUT = ROOT + 'modules/quiz_rpg/scenes/objects/pixel_crawler/stations/'
GROUP = 'stations'
random.seed(11)
used = set()


def uniq():
    while True:
        v = random.randint(10 ** 9, 2 ** 31 - 1)
        if v not in used:
            used.add(v)
            return v


def nid(n=5):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(n))


def uid_of(png):
    return re.search(r'uid="(uid://[^"]+)"', open(ROOT + png + '.import').read()).group(1)


def load(png):
    return np.array(Image.open(ROOT + PACK + png).convert('RGBA'))[:, :, 3] > 0


def tight(a, x0, y0, x1, y1):
    sub = a[y0:y1, x0:x1]
    yy, xx = np.where(sub)
    if len(yy) == 0:
        return None
    return (x0 + int(xx.min()), y0 + int(yy.min()), int(xx.max() - xx.min() + 1), int(yy.max() - yy.min() + 1))


def blobs(a, min_px=300, grow=3):
    """Spójne plamy (po rozdęciu o `grow`, żeby gruz przy obiekcie został z nim) w kolejności wiersz, x."""
    lab, _ = ndimage.label(ndimage.binary_dilation(a, iterations=grow))
    res = []
    for sl in ndimage.find_objects(lab):
        r = tight(a, sl[1].start, sl[0].start, sl[1].stop, sl[0].stop)
        if r and int(a[r[1]:r[1] + r[3], r[0]:r[0] + r[2]].sum()) >= min_px:
            res.append(r)
    return res


def row_runs(a, x0, x1, gap=3, min_h=8):
    """Obiekty ułożone w pionie w paśmie kolumny: serie niepustych wierszy rozdzielone przerwą >= gap."""
    rows = a[:, x0:x1].any(axis=1)
    runs, start, empty = [], None, 0
    for y, v in enumerate(rows):
        if v:
            if start is None:
                start = y
            empty = 0
            end = y
        elif start is not None:
            empty += 1
            if empty >= gap:
                runs.append((start, end + 1))
                start = None
    if start is not None:
        runs.append((start, end + 1))
    out = []
    for y0, y1 in runs:
        r = tight(a, x0, y0, x1, y1)
        if r and r[3] >= min_h:
            out.append(r)
    return out


def cells(a, x0, x1, cuts, snap=6, min_h=8):
    """Obiekty w paśmie kolumny rozcięte po granicach `cuts` (y); każda granica trafia w najpustszy wiersz w oknie +-snap."""
    rows = a[:, x0:x1].sum(axis=1)
    cs = []
    for c in cuts:
        lo, hi = max(0, c - snap), min(len(rows) - 1, c + snap)
        win = rows[lo:hi + 1]
        best = [lo + i for i, v in enumerate(win) if v == win.min()]
        cs.append(min(best, key=lambda y: abs(y - c)))
    out = []
    for y0, y1 in zip(cs[:-1], cs[1:]):
        r = tight(a, x0, y0, x1, y1)
        out.append(r if r and r[3] >= min_h else None)
    return out


def row_of(r, bounds):
    cy = r[1] + r[3] / 2.0
    for i, b in enumerate(bounds):
        if cy < b:
            return i
    return len(bounds)


def reading_order(rects, bounds):
    return sorted(rects, key=lambda r: (row_of(r, bounds), r[0]))


def collision(rect, top_h, inset=1):
    """(pół-szerokość, góra, dół, przesunięcie x) w px od origin — podstawa obiektu o wysokości top_h."""
    w = rect[2]
    return (max(3, w // 2 - inset), -top_h, 2, 0)


def head(png, name):
    title = ''.join(p.capitalize() for p in name.split('_'))
    s = '[gd_scene format=3]\n\n'
    s += f'[ext_resource type="Texture2D" uid="{uid_of(PACK + png)}" path="res://{PACK + png}" id="1_tex"]\n\n'
    return s, title


def body(title, name, sprite, coll):
    s = f'[node name="{title}" type="StaticBody2D" unique_id={uniq()}]\ncollision_layer = 32\ncollision_mask = 0\nmetadata/object_group = "{GROUP}"\n\n'
    s += sprite
    hw, t, b, cxo = coll
    pts = [(-hw + cxo, t + 1), (-hw + cxo + 1, t), (hw + cxo - 1, t), (hw + cxo, t + 1),
           (hw + cxo, b - 1), (hw + cxo - 1, b), (-hw + cxo + 1, b), (-hw + cxo, b - 1)]
    s += f'\n[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="." unique_id={uniq()}]\n'
    s += 'polygon = PackedVector2Array(' + ', '.join(f'{int(px)}, {int(py)}' for px, py in pts) + ')\n'
    return s


def save(name, s):
    os.makedirs(OUT, exist_ok=True)
    open(OUT + name + '.tscn', 'w', newline='\n').write(s)


def write_static(name, png, rect, top_h):
    x, y, w, h = rect
    s, title = head(png, name)
    s += f'[sub_resource type="AtlasTexture" id="AtlasTexture_{nid()}"]\natlas = ExtResource("1_tex")\nregion = Rect2({x}, {y}, {w}, {h})\nfilter_clip = true\n\n'
    sid = re.search(r'id="(AtlasTexture_\w+)"', s).group(1)
    sprite = (f'[node name="Sprite2D" type="Sprite2D" parent="." unique_id={uniq()}]\ntexture = SubResource("{sid}")\n'
              f'centered = false\noffset = Vector2({-int(round(w / 2.0))}, {-(h - 2)})\n')
    save(name, s + body(title, name, sprite, collision(rect, min(top_h, h - 2))))
    print('static', name, rect)


def write_animated(name, png, fw, fh, fps, top_h, flip_empty=True):
    a = load(png)
    cols, rows = a.shape[1] // fw, a.shape[0] // fh
    frames = []
    for r in range(rows):
        for c in range(cols):
            if a[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw].any():
                frames.append((c * fw, r * fh))
    s, title = head(png, name)
    ids = []
    for (x, y) in frames:
        i = f'AtlasTexture_{nid()}'
        ids.append(i)
        s += f'[sub_resource type="AtlasTexture" id="{i}"]\natlas = ExtResource("1_tex")\nregion = Rect2({x}, {y}, {fw}, {fh})\nfilter_clip = true\n\n'
    sf = 'SpriteFrames_' + nid()
    frame_list = ', '.join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % i for i in ids)
    s += f'[sub_resource type="SpriteFrames" id="{sf}"]\nanimations = [{{\n"frames": [{frame_list}],\n"loop": true,\n"name": &"default",\n"speed": {fps}.0\n}}]\n\n'
    sprite = (f'[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="." unique_id={uniq()}]\nsprite_frames = SubResource("{sf}")\n'
              f'autoplay = "default"\ncentered = false\noffset = Vector2({-fw // 2}, {-(fh - 2)})\n')
    # podstawa = szerokość treści na dolnych wierszach klatki
    box = tight(a, frames[0][0], frames[0][1], frames[0][0] + fw, frames[0][1] + fh)
    save(name, s + body(title, name, sprite, collision((0, 0, box[2], box[3]), top_h)))
    print('animated', name, f'{len(frames)} kl.', (fw, fh))


# ---- cięcie statycznych arkuszy ----
def collect():
    items = []  # (name, png, rect, wysokość kolizji)

    a = load('Anvil/Anvil.png')
    bl = blobs(a, 300)
    top = [r for r in bl if r[1] < 100]
    low = [r for r in bl if r[1] >= 100]
    for i, r in enumerate(sorted(top, key=lambda r: r[0])):
        items.append((f'anvil_{i + 1}', 'Anvil/Anvil.png', r, 8))
    for i, r in enumerate(sorted(low, key=lambda r: r[0])):
        items.append((f'anvil_table_{i + 1}', 'Anvil/Anvil.png', r, 8))

    a = load('Furnace/Furnace.png')
    kinds = ['stone', 'brick', 'iron']
    for t, (x0, x1) in enumerate([(0, 40), (46, 100), (106, 192)]):
        for k, r in enumerate(cells(a, x0, x1, [0, 64, 128, 192, 256, 320, 384], snap=4)):
            if r and k >= 3:
                items.append((f'furnace_{kinds[k % 3]}_{t + 1}_off', 'Furnace/Furnace.png', r, 10))

    a = load('Workbench/Workbench.png')
    kinds = ['stone', 'wood', 'metal']
    for t, (x0, x1, cuts) in enumerate([(0, 40, [0, 64, 120, 170, 240, 300, 352]),
                                        (44, 100, [0, 60, 113, 170, 240, 291, 352]),
                                        (100, 192, [0, 64, 113, 178, 242, 291, 352])]):
        for k, r in enumerate(cells(a, x0, x1, cuts)):
            if r:
                items.append((f'workbench_{kinds[k % 3]}_{t + 1}_{"tools" if k < 3 else "empty"}', 'Workbench/Workbench.png', r, 8))

    for png, suffix in (('Cooking Station/Cooking Station.png', ''), ('Cooking Station/Estructure.png', '_empty')):
        a = load(png)
        names = ['spit_small', 'spit_cauldron', 'grill_ham', 'grill_big',
                 'cauldron_tripod', 'cauldron_stand', 'stove', 'kitchen_big',
                 'chopping_block', 'butcher_table', 'butcher_stall', 'butcher_stall_big']
        rects = [r for r in blobs(a, 250) if r[2] >= 14 and r[3] >= 14]
        for nm, r in zip(names, reading_order(rects, (70, 155))):
            items.append((f'cooking_{nm}{suffix}', png, r, 8))

    a = load('Sawmill/Base.png')
    small = [r for r in blobs(a, 150, grow=2) if r[3] >= 12 and r[0] < 140]
    for nm, r in zip(['chopping_block', 'sawmill_2', 'stump', 'sawmill_2_base'], reading_order(small, (80,))):
        items.append((f'sawmill_{nm}' if nm.startswith(('chopping', 'stump')) else nm, 'Sawmill/Base.png', r, 8))
    for nm, r in zip(['sawmill_3', 'sawmill_3_base'], cells(a, 140, 256, [0, 80, 144], snap=8)):
        items.append((nm, 'Sawmill/Base.png', r, 10))
    return items


def preview(items):
    by_png = {}
    for it in items:
        by_png.setdefault(it[1], []).append(it)
    tmp = os.environ.get('TEMP', '.')
    for png, lst in by_png.items():
        im = Image.open(ROOT + PACK + png).convert('RGBA')
        sc = 3
        out = Image.new('RGBA', im.size, (90, 110, 90, 255))
        out.alpha_composite(im)
        out = out.resize((im.width * sc, im.height * sc), Image.NEAREST)
        d = ImageDraw.Draw(out)
        for nm, _, (x, y, w, h), _ in lst:
            d.rectangle([x * sc, y * sc, (x + w) * sc, (y + h) * sc], outline=(255, 0, 255, 255))
            d.text((x * sc + 2, y * sc + 2), nm, fill=(255, 255, 0, 255))
        fn = os.path.join(tmp, 'stations_prev_' + png.replace('/', '_'))
        out.convert('RGB').save(fn)
        print('preview', fn, len(lst))


# (nazwa, arkusz, szer. klatki, wys. klatki, fps, wysokość kolizji); klatki puste są pomijane
ANIMATED = [
    ('alchemy_table_1', 'Alchemy/Alchemy_Table_01-Sheet.png', 32, 64, 10, 8),
    ('alchemy_table_2', 'Alchemy/Alchemy_Table_02-Sheet.png', 48, 64, 10, 8),
    ('alchemy_table_3', 'Alchemy/Alchemy_Table_03-Sheet.png', 80, 80, 10, 10),
    ('anvil_1_anim', 'Anvil/Anvil_01-Sheet.png', 64, 80, 8, 8),
    ('anvil_2_anim', 'Anvil/Anvil_02-Sheet.png', 80, 80, 8, 8),
    ('anvil_3_anim', 'Anvil/Anvil_03-Sheet.png', 96, 80, 8, 8),
    ('sawmill_2_anim', 'Sawmill/Level_2-Sheet.png', 80, 64, 10, 8),
    ('sawmill_3_anim', 'Sawmill/Level_3-Sheet.png', 112, 80, 10, 10),
    ('cooking_spit_small_anim', 'Cooking Station/Grill/Grill_01-Sheet.png', 64, 64, 6, 8),
    ('cooking_spit_cauldron_anim', 'Cooking Station/Grill/Grill_02-Sheet.png', 64, 64, 6, 8),
    ('cooking_grill_ham_anim', 'Cooking Station/Grill/Grill_03-Sheet.png', 64, 64, 6, 8),
    ('cooking_grill_big_anim', 'Cooking Station/Grill/Grill_04-Sheet.png', 80, 64, 6, 8),
    ('cooking_stove_anim', 'Cooking Station/Cooker/Cooker_03-Sheet.png', 48, 32, 6, 8),
    ('cooking_kitchen_big_anim', 'Cooking Station/Cooker/Cooker_04-Sheet.png', 80, 80, 6, 10),
]
for _p in ('Stone', 'Bricks', 'Iron'):
    for _t, (_fw, _fh) in enumerate([(32, 48), (48, 64), (48, 64)]):
        ANIMATED.append((f'furnace_{_p.lower().replace("bricks", "brick")}_{_t + 1}_on', f'Furnace/{_p}_0{_t + 1}-Sheet.png', _fw, _fh, 6, 10))

if __name__ == '__main__':
    items = collect()
    if '--preview' in sys.argv:
        preview(items)
        sys.exit()
    for name, png, rect, top_h in items:
        write_static(name, png, rect, top_h)
    for name, png, fw, fh, fps, top_h in ANIMATED:
        write_animated(name, png, fw, fh, fps, top_h)
