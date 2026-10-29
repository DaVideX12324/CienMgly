"""Tekstura drabiny w stylu Pixel Crawlera (miedź ścieków i jasnosiwe żelazo): 16 px szerokości, powtarzalna w pionie co RUNG px.

Kontur (20, 20, 18) jak w Pixel Crawlerze; rampy materiałów w MATERIALS (miedź z sewer/Assets).
Dwie szyny po bokach (kontur, odblask, jasna, średnia, ciemna), szczeble co RUNG px (górna krawędź jasna, dolna ciemna). Wynik: assets/pixel_crawler/environments/sewer/Assets/Ladder.png i Ladder_Iron.png (texture_repeat w scenie).
Użycie: python gen_ladder.py [--preview <plik.png>]
"""
import os, sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
OUT_DIR = ROOT + 'assets/pixel_crawler/environments/sewer/Assets/'
W, RUNG, RUNGS = 16, 8, 6

OUTLINE = (20, 20, 18)
## Materiały: plik wynikowy i rampa (odblask, jasna, średnia, ciemna).
MATERIALS = {
    'miedz': ('Ladder.png', [(255, 224, 213), (219, 151, 126), (163, 95, 70), (106, 57, 39)]),
    'zelazo': ('Ladder_Iron.png', [(255, 255, 255), (214, 214, 210), (168, 168, 164), (120, 120, 118)]),
}


def build(ramp: list) -> Image.Image:
    HI, LIGHT, MID, DARK = ramp
    h = RUNG * RUNGS
    im = Image.new('RGBA', (W, h), (0, 0, 0, 0))
    px = im.load()

    def put(x, y, c):
        px[x, y % h] = c + (255,)

    for y in range(h):
        # szczebel: rzędy 2-3 okresu (jasna góra, ciemny dół), kontur nad i pod
        r = y % RUNG
        if r in (1, 2, 3, 4):
            c = {1: OUTLINE, 2: LIGHT, 3: DARK, 4: OUTLINE}[r]
            for x in range(4, 12):
                put(x, y, c)
        # szyny: lewa x 1-4, prawa x 11-14 (kontur zewnętrzny i wewnętrzny)
        for x0 in (1, 11):
            put(x0, y, OUTLINE)
            put(x0 + 1, y, HI if x0 == 1 else LIGHT)
            put(x0 + 2, y, MID if x0 == 1 else DARK)
            put(x0 + 3, y, OUTLINE)
        # nity na szynach przy szczeblach
        if r in (2, 3):
            put(3, y, LIGHT if r == 2 else DARK)
            put(12, y, LIGHT if r == 2 else DARK)
    return im


if __name__ == '__main__':
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else ''
    bg = Image.new('RGBA', (W * (2 * len(MATERIALS) + 1), RUNG * RUNGS * 2), (14, 17, 19, 255))
    for k, (name, (file, ramp)) in enumerate(MATERIALS.items()):
        img = build(ramp)
        img.save(OUT_DIR + file)
        print(name, '->', OUT_DIR + file, img.size)
        for j in range(2):
            bg.alpha_composite(img, (W * (2 * k + 1), j * img.height))
    if preview:
        bg.resize((bg.width * 6, bg.height * 6), Image.NEAREST).save(preview)
