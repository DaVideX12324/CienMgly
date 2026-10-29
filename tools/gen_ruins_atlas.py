"""Atlas ruin Ruins.png (Pixel Crawler, Props/Static) — elementy z paczek Pixel Crawlera i własny gruz:
- Desert (nieużywane): obeliski, ceglane słupy, dzbany — przekolorowane rampą jasności (kamień zamku, piaskowiec),
- zamek: złamane kolumny, bloki, popiersia (złamania dorysowane: wyszczerbiona krawędź, jaśniejszy przełom),
- ścieki: filar leżący (oryginał) i wszystkie filary w kamieniu (stojące oryginały: sewer/Assets/Tiles.png),
- kuźnia (nieużywane): posąg w trzech stanach, w kamieniu; cmentarz (nieużywane): rozbite nagrobki,
- własny gruz: bloki, stos, słup, mur, odłamki (kamień i piaskowiec),
- miasto (zamienniki Desert Oasis): zrujnowany mur z lica muru zamku, drogowskaz, tablice (menu, ogłoszenia), bale z pnia
  drzewa, łopata z cmentarza, szczątki szkieleta (ostatnia klatka śmierci).
Elementy bez zmian z plików widocznych w Godocie (poza _nieuzywane) nie trafiają tu — sceny biorą je z oryginałów.
Każdy element w osobnym slocie siatki 16 px (dół sprite'a = dół slotu, środek w poziomie).
Uruchomienie: python -I gen_ruins_atlas.py  ->  Ruins.png + lista regionów (nazwa, Rect2) na wyjściu."""
import os
import random

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
A = os.path.join(ROOT, "assets")
PC = os.path.join(A, "pixel_crawler")
STATIC = os.path.join(PC, "packs/free_pack_2.11/Pixel Crawler - Free Pack/Environment/Props/Static")
UNUSED = os.path.join(A, "_nieuzywane/pixel_crawler/environments")
OUT_PATH = os.path.join(STATIC, "Ruins.png")
ATLAS_W = 512
CELL = 16

OUT = (20, 20, 18)
RAMPS = {
    "kamien": ((28, 23, 44), [(53, 37, 51), (73, 64, 59), (104, 97, 81), (117, 109, 90), (143, 134, 113), (163, 154, 133)]),
    "piaskowiec": ((40, 30, 26), [(112, 84, 58), (150, 118, 86), (182, 150, 116), (209, 188, 164), (224, 208, 188), (236, 224, 206)]),
}
BLOCK_PALETTES = {  # wierzch, wierzch cień, lico, lico ciemne, pęknięcie
    "kamien": [(146, 137, 127), (132, 124, 113), (96, 88, 80), (72, 66, 59), (44, 41, 37)],
    "piaskowiec": [(224, 208, 188), (209, 188, 164), (182, 150, 116), (150, 118, 86), (112, 84, 58)],
}


def load(*parts):
    return Image.open(os.path.join(*parts)).convert("RGBA")


def trim(im):
    return im.crop(im.getbbox())


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def lighter(c, v):
    return tuple(min(255, x + v) for x in c[:3]) + (255,)


# --- przekolorowanie -------------------------------------------------------------------------------------------

def recolor(im, ramp_name, keep_blue=True):
    """Kolory nieprzezroczyste -> rampa wg jasności; najciemniejszy ton (kontur) -> kontur rampy; niebieskie bez zmian."""
    out_col, ramp = RAMPS[ramp_name]
    opaque = {p[:3] for p in im.get_flattened_data() if p[3] == 255}
    darkest = min(lum(c) for c in opaque)
    outline = {c for c in opaque if lum(c) < min(45, darkest + 6)}
    cols = sorted((c for c in opaque - outline if not (keep_blue and c[2] > c[0] + 20)), key=lum)
    mapping = {c: out_col for c in outline}
    if cols:
        lo, hi = lum(cols[0]), lum(cols[-1])
        for c in cols:
            f = (lum(c) - lo) / max(1, hi - lo) * (len(ramp) - 1)
            i = min(int(f), len(ramp) - 2)
            k = f - i
            mapping[c] = tuple(round(ramp[i][j] * (1 - k) + ramp[i + 1][j] * k) for j in range(3))
    res = im.copy()
    px = res.load()
    for y in range(res.height):
        for x in range(res.width):
            p = px[x, y]
            if p[3] == 255 and p[:3] in mapping:
                px[x, y] = mapping[p[:3]] + (255,)
    return res


# --- złamania (zamek, ścieki) ----------------------------------------------------------------------------------

def cut_top(im, keep_from, depth, seed, outline=OUT):
    """Zdejmuje górę po wyszczerbionej linii (keep_from ± depth); przełom: kontur + jaśniejszy pas 2 px."""
    rng = random.Random(seed)
    im = im.copy()
    w, h = im.size
    px = im.load()
    off = 0
    for x in range(w):
        off = min(max(off + rng.choice((-1, 0, 1, 1, -2, 2)), -depth), depth)
        cy = max(0, min(h - 1, keep_from + off))
        for y in range(cy):
            px[x, y] = (0, 0, 0, 0)
        if px[x, cy][3]:
            px[x, cy] = outline + (255,)
            for k in (1, 2):
                if cy + k < h and px[x, cy + k][3] and lum(px[x, cy + k]) >= 45:
                    px[x, cy + k] = lighter(px[x, cy + k], 28 if k == 1 else 14)
    return trim(im)


def cut_right(im, keep_to, depth, seed):
    r = im.rotate(90, expand=True)
    return cut_top(r, r.height - keep_to, depth, seed).rotate(-90, expand=True)


def lay(im):
    return trim(im.rotate(-90, expand=True))


def compose(parts, w, h):
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for im, x, base in parts:
        c.alpha_composite(im, (x, base - im.height))
    return trim(c)


# --- własny gruz (bloki w rzucie 3/4) --------------------------------------------------------------------------

class Canvas:
    def __init__(self, w, h):
        self.w, self.h, self.px = w, h, {}

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def clear(self, x, y):
        self.px.pop((x, y), None)

    def block(self, x, y, w, d, h, pal, rng, chips=True, crack=True):
        top, top_s, face, face_d, cr = pal
        x0, y0, x1, y1 = x - 1, y - 1, x + w, y + d + h
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                if xx in (x0, x1) and yy in (y0, y1):
                    self.clear(xx, yy)
                elif xx in (x0, x1) or yy in (y0, y1):
                    self.put(xx, yy, OUT)
                elif yy < y + d:
                    self.put(xx, yy, lighter(top, 12)[:3] if yy == y else (top_s if yy == y + d - 1 else top))
                else:
                    self.put(xx, yy, face_d if yy == y + d + h - 1 or xx == x + w - 1 else face)
        for cx in (x, x + w - 1):
            self.put(cx, y, OUT)
            self.put(cx, y + d + h - 1, OUT)
        if chips:
            for _ in range(rng.randrange(0, 3)):
                cx = rng.randrange(x + 1, x + w - 1)
                self.clear(cx, y0)
                self.put(cx, y, OUT)
        if crack and w >= 7 and h >= 5:
            cx, yy = x + rng.randrange(2, w - 3), y + d
            for _ in range(rng.randrange(3, 5)):
                self.put(cx, yy, cr)
                yy += 1
                cx += rng.choice((0, 1))

    def column(self, x, base, w, h, pal, rng, depth=5):
        top, top_s, face, face_d, cr = pal
        cut, cols = 0, []
        for _ in range(w):
            cut = min(max(cut + rng.choice((-1, 0, 1, 1, 2)), 0), depth)
            cols.append(cut)
        cols[0], cols[-1] = max(cols[0], 1), max(cols[-1], 2)
        for i, c in enumerate(cols):
            xx, ytop = x + i, base - h + c
            self.put(xx, ytop - 1, OUT)
            for k, yy in enumerate(range(ytop, base)):
                col = (lighter(top, 12)[:3] if k == 0 else top_s) if k < 2 else (face_d if i == w - 1 or yy == base - 1 else face)
                self.put(xx, yy, col)
            self.put(xx, base, OUT)
        for i, xx in ((0, x - 1), (w - 1, x + w)):
            for yy in range(base - h + cols[i], base):
                self.put(xx, yy, OUT)
        cx, yy = x + w // 2, base - h // 2
        for _ in range(4):
            self.put(cx, yy, cr)
            yy += 1
            cx = min(max(cx + rng.choice((-1, 0, 1)), x + 1), x + w - 2)

    def slab(self, x, y, w, d, h, slope, pal):
        top, top_s, face, face_d, cr = pal
        for i in range(w):
            yy0 = y - int(i * slope)
            for k in range(d + h):
                col = (lighter(top, 12)[:3] if k == 0 else (top_s if k == d - 1 else top)) if k < d else \
                    (face_d if k == d + h - 1 or i == w - 1 else face)
                self.put(x + i, yy0 + k, col)

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        out = im.copy()
        for y in range(self.h):
            for x in range(self.w):
                if im.getpixel((x, y))[3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if 0 <= x + dx < self.w and 0 <= y + dy < self.h:
                        p = im.getpixel((x + dx, y + dy))
                        if p[3] and p[:3] != OUT:
                            out.putpixel((x, y), OUT + (255,))
                            break
        return trim(out)


def rubble(kind, pal, seed):
    rng = random.Random(seed)
    if kind == "blok":
        c = Canvas(14, 14); c.block(2, 4, 10, 4, 6, pal, rng)
    elif kind == "blok_dlugi":
        c = Canvas(22, 12); c.block(2, 2, 18, 4, 5, pal, rng)
    elif kind == "bloki_stos":
        c = Canvas(22, 20); c.block(2, 9, 18, 4, 6, pal, rng); c.block(6, 3, 10, 4, 5, pal, rng)
    elif kind == "slup":
        c = Canvas(14, 32); c.column(2, 30, 10, 26, pal, rng)
    elif kind == "mur":
        c = Canvas(28, 22)
        c.block(5, 3, 9, 4, 5, pal, rng); c.block(15, 5, 7, 3, 5, pal, rng)
        c.block(2, 10, 8, 4, 6, pal, rng); c.block(10, 10, 8, 4, 6, pal, rng); c.block(18, 10, 8, 4, 6, pal, rng)
    elif kind == "blok_pekniety":
        c = Canvas(26, 14); c.block(2, 4, 10, 4, 6, pal, rng, crack=False); c.block(14, 5, 10, 4, 5, pal, rng, crack=False)
    elif kind == "blok_przewrocony":
        c = Canvas(24, 20); c.slab(2, 11, 20, 3, 5, 0.4, pal)
    else:  # odlamki
        c = Canvas(22, 12)
        for (x, y, w) in ((9, 2, 4), (2, 5, 5), (14, 6, 5), (8, 8, 3)):
            c.block(x, y, w, 2, 2, pal, rng, chips=False, crack=False)
    return c.image()


RUBBLE_KINDS = ["blok", "blok_dlugi", "bloki_stos", "slup", "mur", "blok_pekniety", "blok_przewrocony", "odlamki"]


# --- miasto: zamienniki obiektów Desert Oasis (mur, drogowskaz, tablice, bale) -----------------------------------

K = (0, 0, 0)                                                                       # kontur mebli Pixel Crawlera
WOOD = [(47, 28, 16), (90, 54, 30), (125, 76, 40), (160, 97, 49), (186, 120, 66)]   # Furniture.png (+ rozjaśnienie)
SLATE = [(34, 40, 39), (46, 54, 52), (58, 68, 66)]
CHALK = (206, 206, 194)
PAPER = [(206, 196, 170), (232, 224, 202), (150, 140, 120)]
PIN = (170, 50, 40)


class Px:
    """Płótno do rysowania pikseli z obrysem na zewnątrz (kolor konturu)."""

    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.im.load()
        self.w, self.h = w, h

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = c + (255,)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def outlined(self, col=K):
        s = self.im.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if not s[x, y][3] and any(0 <= x + dx < self.w and 0 <= y + dy < self.h and s[x + dx, y + dy][3]
                                          and s[x + dx, y + dy][:3] != col for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.p[x, y] = col + (255,)
        return trim(self.im)


def ruined_wall(castle, width, seed):
    """Zrujnowany mur z lica muru zamku: szczyt opada schodkami w prawo, przełom jaśniejszy, gruz u podstawy."""
    out_col = RAMPS["kamien"][0]
    wall = Image.new("RGBA", (width, 40), (0, 0, 0, 0))
    for x in range(0, width, 48):
        wall.alpha_composite(castle.crop((16, 80, 64, 112)), (x, 8))
    rng = random.Random(seed)
    prof = []
    for w, top in [(14, 0), (10, 5), (8, 2), (12, 12), (10, 19), (10, 24), (8, 28)]:
        prof += [top + rng.choice((0, 0, 1, -1)) for _ in range(w)]
    prof = (prof + [prof[-1]] * width)[:width]
    p = wall.load()
    for x in range(width):
        y = max(0, prof[x]) + 8
        for yy in range(y):
            p[x, yy] = (0, 0, 0, 0)
        if y < wall.height and p[x, y][3]:
            p[x, y] = out_col + (255,)
            for k, v in ((1, 30), (2, 14)):
                if y + k < wall.height and p[x, y + k][3]:
                    p[x, y + k] = lighter(p[x, y + k], v)
    c = Px(width + 2, wall.height)
    c.im.alpha_composite(wall, (1, 0))
    body = c.outlined(out_col)
    res = Image.new("RGBA", (width + 30, body.height + 3), (0, 0, 0, 0))
    res.alpha_composite(body, (0, 0))
    pal = BLOCK_PALETTES["kamien"]
    for kind, s, x in (("blok", 7, width - 4), ("odlamki", 14, width + 8), ("blok_pekniety", 12, 20)):
        im = rubble(kind, pal, s)
        res.alpha_composite(im, (x, body.height + 3 - im.height))
    return trim(res)


def signpost():
    c = Px(30, 34)
    c.rect(13, 2, 16, 33, WOOD[2])                       # słupek
    for y in range(2, 34):
        c.put(13, y, WOOD[3])
        c.put(16, y, WOOD[1])
    c.put(14, 2, WOOD[4])
    c.put(15, 2, WOOD[3])
    for x0, y0, w, right in ((6, 6, 22, True), (2, 15, 18, False)):   # deski-strzałki
        for y in range(y0, y0 + 7):
            for x in range(x0, x0 + w):
                d = (x0 + w - 1 - x) if right else (x - x0)
                if d < min(3, abs(y - (y0 + 3))):
                    continue
                c.put(x, y, WOOD[4] if y == y0 else (WOOD[1] if y == y0 + 6 else (WOOD[2] if y == y0 + 3 else WOOD[3])))
        c.put(x0 + (2 if right else w - 3), y0 + 3, K)    # gwóźdź
    return c.outlined()


def menu_board():
    c = Px(18, 26)
    c.rect(1, 1, 16, 21, WOOD[2])                        # rama
    for y in range(1, 22):
        c.put(1, y, WOOD[3])
        c.put(16, y, WOOD[1])
    for x in range(1, 17):
        c.put(x, 1, WOOD[4])
        c.put(x, 21, WOOD[1])
    c.rect(3, 3, 14, 19, SLATE[1])                       # łupek
    for x in range(3, 15):
        c.put(x, 3, SLATE[0])
    for y in range(3, 20):
        c.put(14, y, SLATE[2])
    for y, (a, b) in zip((6, 9, 12, 15), ((5, 12), (5, 10), (5, 12), (5, 9))):   # kreda
        for x in range(a, b + 1):
            if x % 3 != 1:
                c.put(x, y, CHALK)
    for x0 in (2, 14):                                   # nóżki
        for y in range(22, 25):
            c.put(x0, y, WOOD[2])
            c.put(x0 + 1, y, WOOD[1])
    return c.outlined()


def bulletin_board():
    c = Px(34, 32)
    for x0 in (3, 28):                                   # słupki
        c.rect(x0, 4, x0 + 2, 31, WOOD[2])
        for y in range(4, 32):
            c.put(x0, y, WOOD[3])
            c.put(x0 + 2, y, WOOD[1])
    c.rect(1, 2, 32, 4, WOOD[3])                         # daszek
    for x in range(1, 33):
        c.put(x, 2, WOOD[4])
        c.put(x, 4, WOOD[1])
    for y in range(6, 22):                               # tablica z poziomych desek
        for x in range(2, 32):
            c.put(x, y, WOOD[3] if y == 6 else (WOOD[0] if y == 21 else (WOOD[2] if (y - 6) % 5 else WOOD[1])))
    for x0, y0, w, h in ((5, 8, 7, 9), (14, 9, 6, 7), (22, 8, 7, 10), (13, 17, 5, 3)):   # kartki
        c.rect(x0, y0, x0 + w - 1, y0 + h - 1, PAPER[1])
        for y in range(y0, y0 + h):
            c.put(x0 + w - 1, y, PAPER[0])
        for y in range(y0 + 2, y0 + h - 1, 2):
            for x in range(x0 + 1, x0 + w - 2):
                c.put(x, y, PAPER[2])
        c.put(x0 + w // 2, y0, PIN)
    return c.outlined()


def tree_log(trees, length):
    """Bal: prosty odcinek pnia martwego dębu (Trees/Model_01/Size_04) położony na boku, czoło = przekrój pniaka."""
    strip = trees.crop((191, 96, 207, 116))
    trunk = Image.new("RGBA", (16, length), (0, 0, 0, 0))
    for y in range(0, length, strip.height):
        trunk.alpha_composite(strip, (0, y))
    log_im = trunk.rotate(90, expand=True)
    cap = trees.crop((337, 8, 351, 16)).rotate(90, expand=True)
    c = Px(length + cap.width + 2, 18)
    c.im.alpha_composite(log_im, (cap.width // 2 + 1, 1))
    c.im.alpha_composite(cap, (1, 1 + (16 - cap.height) // 2))
    return c.outlined(min({p[:3] for p in log_im.get_flattened_data() if p[3] == 255}, key=sum))


def tree_log_pile(trees):
    a, b, top = tree_log(trees, 30), tree_log(trees, 26), tree_log(trees, 24)
    res = Image.new("RGBA", (44, 34), (0, 0, 0, 0))
    res.alpha_composite(top, (10, 0))
    res.alpha_composite(a, (0, 34 - a.height))
    res.alpha_composite(b, (12, 34 - a.height - 9))
    return trim(res)


# --- elementy ---------------------------------------------------------------------------------------------------

def groups():
    """Lista grup (wiersze atlasu): [(nazwa, obraz)]."""
    desert = load(UNUSED, "desert/Assets/Props.png")
    castle = load(PC, "environments/castle/Assets/Tiles.png")
    sewer = load(PC, "environments/sewer/Assets/Tiles.png")
    forge = load(UNUSED, "forge/Assets/Tiles.png")
    graves = load(UNUSED, "cemetery/Pixel Crawler - Cemetery/Environment/Props/Graves.png")
    rocks = load(STATIC, "Rocks.png")
    pebbles = [rocks.crop(b) for b in ((180, 37, 188, 43), (165, 54, 172, 60), (181, 54, 189, 60), (148, 70, 155, 75), (132, 85, 140, 91))]

    d_items = [("obelisk", (0, 0, 32, 128)), ("obelisk_ulamany", (32, 0, 64, 128)), ("obelisk_rozbity", (64, 0, 96, 128)),
               ("slup_ceglany", (0, 128, 32, 176)), ("slup_ceglany_zlamany", (32, 128, 64, 176)), ("slup_ceglany_kikut", (64, 128, 96, 176)),
               ("dzban", (97, 78, 111, 96)), ("dzban_waski", (115, 74, 125, 96)), ("dzban_rozbity", (129, 83, 143, 96)),
               ("dzban_rozbity_maly", (147, 83, 157, 96))]
    d_base = [(n, trim(desert.crop(b))) for n, b in d_items]

    column = castle.crop((192, 0, 208, 52))
    block = castle.crop((130, 84, 158, 110))
    bust = castle.crop((279, 75, 297, 107))
    bust_helm = castle.crop((342, 75, 362, 107))
    p = pebbles
    col_broken = cut_top(column, 20, 3, 1)
    col_stump = cut_top(column, 33, 1, 2)
    capital = trim(column.crop((0, 0, 16, 9)))
    col_lying = cut_right(lay(cut_top(column, 9, 0, 3)), 30, 2, 4)
    castle_items = [
        ("kolumna_zlamana", compose([(col_broken, 4, 40), (p[0], 0, 41), (p[3], 19, 40)], 30, 44)),
        ("kolumna_kikut", compose([(col_stump, 6, 20), (p[1], 0, 22), (p[2], 20, 21)], 30, 24)),
        ("kolumna_lezaca", compose([(capital, 36, 12), (col_lying, 0, 22), (p[4], 30, 24)], 56, 26)),
        ("blok_zamek", compose([(cut_top(block, 3, 2, 8), 2, 28), (p[0], 0, 30), (p[2], 27, 29)], 36, 32)),
        ("bloki_zamek_stos", compose([(block, 0, 40), (cut_top(block, 2, 2, 9), 7, 22), (p[1], 26, 41)], 40, 44)),
        ("popiersie_przewrocone", compose([(lay(bust), 0, 20), (p[3], 32, 20)], 40, 22)),
        ("posag_bez_glowy", compose([(cut_top(bust_helm, 14, 2, 5), 2, 24), (p[0], 18, 25)], 28, 27)),
    ]

    pillar, pillar_broken, pillar_stump = (trim(sewer.crop((x, 48, x + 16, 120))) for x in (192, 208, 224))
    sewer_items = [("filar", pillar), ("filar_ulamany", pillar_broken), ("filar_kikut", pillar_stump),
                   ("filar_lezacy", compose([(cut_right(lay(pillar), 48, 2, 6), 0, 18), (p[2], 50, 19)], 60, 22))]

    forge_items = [("posag", trim(forge.crop((192, 150, 222, 208)))), ("posag_rozbity", trim(forge.crop((225, 160, 253, 208)))),
                   ("posag_cokol", trim(forge.crop((225, 210, 253, 242))))]
    grave_items = [("nagrobek_rozbity_%d" % (i + 1), trim(graves.crop((i * 16, 64, i * 16 + 16, 96)))) for i in range(3)]

    out = []
    for ramp in ("kamien", "piaskowiec"):
        out.append([("desert_%s_%s" % (n, ramp), recolor(im, ramp)) for n, im in d_base])
    out.append([("zamek_" + n, im) for n, im in castle_items])
    out.append([("sciek_" + n, im) for n, im in sewer_items if n == "filar_lezacy"])  # reszta bez zmian: Tiles.png
    out.append([("sciek_%s_kamien" % n, recolor(im, "kamien", keep_blue=False)) for n, im in sewer_items])
    out.append([("kuznia_%s_kamien" % n, recolor(im, "kamien", keep_blue=False)) for n, im in forge_items] +
               [("cmentarz_" + n, im) for n, im in grave_items])
    for pal in ("kamien", "piaskowiec"):
        out.append([("gruz_%s_%s" % (k, pal), rubble(k, BLOCK_PALETTES[pal], 7 + i)) for i, k in enumerate(RUBBLE_KINDS)])

    trees = load(STATIC, "Trees/Model_01/Size_04.png")
    cemetery = load(UNUSED, "cemetery/Pixel Crawler - Cemetery/Environment/Props/Props.png")
    skeleton = load(PC, "packs/free_pack_2.11/Pixel Crawler - Free Pack/Entities/Mobs/Skeleton Crew/Skeleton - Base/Death/Death-Sheet.png")
    out.append([("mur_zrujnowany", ruined_wall(castle, 72, 3)), ("mur_zrujnowany_maly", ruined_wall(castle, 40, 9))])
    out.append([("drogowskaz", signpost()), ("tablica_menu", menu_board()), ("tablica_ogloszen", bulletin_board()),
                ("bal", tree_log(trees, 30)), ("bale_stos", tree_log_pile(trees)),
                ("lopata", trim(cemetery.crop((82, 49, 93, 80)))), ("lopata_kopiec", trim(cemetery.crop((128, 48, 159, 80)))),
                ("szczatki", trim(skeleton.crop((704, 0, 768, 64))))])  # klatka animacji śmierci jako obiekt
    return out


def ceil16(v):
    return (v + CELL - 1) // CELL * CELL


def pack(rows):
    """Półki: każdy element w slocie zaokrąglonym do 16 px; nowa grupa = nowa półka."""
    placed, x, y, shelf_h = [], 0, 0, 0
    for row in rows:
        if x:
            x, y, shelf_h = 0, y + shelf_h, 0
        for name, im in row:
            sw, sh = ceil16(im.width), ceil16(im.height)
            if x + sw > ATLAS_W:
                x, y, shelf_h = 0, y + shelf_h, 0
            ox, oy = x + (sw - im.width) // 2, y + sh - im.height
            placed.append((name, im, ox, oy))
            x += sw
            shelf_h = max(shelf_h, sh)
    return placed, y + shelf_h


def main():
    placed, h = pack(groups())
    atlas = Image.new("RGBA", (ATLAS_W, ceil16(h)), (0, 0, 0, 0))
    for name, im, x, y in placed:
        atlas.alpha_composite(im, (x, y))
        print("%-45s Rect2(%d, %d, %d, %d)" % (name, x, y, im.width, im.height))
    atlas.save(OUT_PATH)
    print("zapisano", OUT_PATH, atlas.size, len(placed), "elementów")


if __name__ == "__main__":
    main()
