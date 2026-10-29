"""Manekin treningowy na bazie stracha na wróble z Pixel Crawlera (Farm.png, region 244,33 24x47).

Kapelusz i głowa zastąpione workiem (okrągła głowa z juty, sznurek na szyi), niebieskie / morskie ubranie
przemalowane na jutę, na piersi czerwono-biała tarcza. Słupek i ramiona bez zmian.
Wariant obrotowy (kwintana): słupek z obrotową belką — okrągła tarcza po lewej, worek z piaskiem na sznurze po prawej.
Wynik: assets/pixel_crawler/environments/town/Training_Dummy.png i Training_Dummy_Spin.png (24x47, ten sam punkt zaczepienia co strach).
Użycie: python gen_training_dummy.py [--preview <plik.png>]
"""
import os, sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
SRC = ROOT + 'assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png'
REGION = (244, 33, 268, 80)
OUT = ROOT + 'assets/pixel_crawler/environments/town/Training_Dummy.png'
OUT_SPIN = ROOT + 'assets/pixel_crawler/environments/town/Training_Dummy_Spin.png'

OUTLINE = (0, 0, 0)
## Juta: jasna, średnia, ciemna, cień (rampa słomy z Farm.png).
JUTE = [(200, 164, 87), (168, 138, 73), (126, 108, 69), (102, 88, 59)]
ROPE = [(118, 69, 29), (84, 53, 26)]
RED, WHITE = (190, 52, 48), (232, 220, 196)
## Kolory ubrania stracha -> juta (jasne -> jasna itd.).
RECOLOR = {
    (203, 224, 232): JUTE[0], (132, 166, 179): JUTE[1], (39, 124, 174): JUTE[1], (27, 146, 215): JUTE[0],
    (24, 82, 116): JUTE[2], (37, 79, 96): JUTE[2], (26, 53, 64): JUTE[3],
}
HEAD_ROWS = 17          # kapelusz + twarz stracha (wiersze 0..16)
HEAD_C, HEAD_R = (11.5, 11.0), 5.7
## Korpus stracha ma parzystą szerokość (środek x 11,5), więc tarcza też parzysta: 8x8 od x 8.
TARGET_TL = (8, 20)
TARGET = ['..RRRR..', '.RWWWWR.', 'RWWRRWWR', 'RWRRRRWR', 'RWRRRRWR', 'RWWRRWWR', '.RWWWWR.', '..RRRR..']


def build() -> Image.Image:
    im = Image.open(SRC).convert('RGBA').crop(REGION)
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] and c[:3] in RECOLOR:
                px[x, y] = RECOLOR[c[:3]] + (255,)
    # głowa: czyścimy kapelusz, rysujemy okrągły worek z cieniem po prawej / dole
    for y in range(HEAD_ROWS):
        for x in range(w):
            px[x, y] = (0, 0, 0, 0)
    cx, cy = HEAD_C
    for y in range(HEAD_ROWS + 1):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = (dx * dx + dy * dy) ** 0.5
            if d <= HEAD_R:
                shade = 0 if dx + dy < -2.5 else 1 if dx + dy < 2.0 else 2
                px[x, y] = (OUTLINE if d > HEAD_R - 1 else JUTE[shade]) + (255,)
    # szwy na worku (krzyżyk) i węzeł sznurka na szyi
    for x, y in ((10, 9), (13, 9), (11, 10), (12, 10), (11, 11), (12, 11), (10, 12), (13, 12)):
        px[x, y] = JUTE[3] + (255,)
    for x in range(9, 15):
        px[x, HEAD_ROWS - 1] = ROPE[0 if x % 2 else 1] + (255,)
    px[8, HEAD_ROWS - 1] = px[15, HEAD_ROWS - 1] = OUTLINE + (255,)
    # tarcza na piersi
    tx, ty = TARGET_TL
    for j, row in enumerate(TARGET):
        for i, ch in enumerate(row):
            if ch != '.':
                px[tx + i, ty + j] = (RED if ch == 'R' else WHITE) + (255,)
    return im


## Drewno słupka i belki (rampa z Farm.png).
WOOD = [(168, 138, 73), (118, 69, 29), (84, 53, 26), (57, 39, 24)]
METAL = [(203, 224, 232), (132, 166, 179)]


def build_spin() -> Image.Image:
    src = Image.open(SRC).convert('RGBA').crop(REGION)
    im = Image.new('RGBA', src.size, (0, 0, 0, 0))
    px, sp = im.load(), src.load()
    w, h = im.size
    # podstawa słupka (nogi) ze stracha
    for y in range(38, h):
        for x in range(w):
            px[x, y] = sp[x, y]

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c + (255,)

    # słupek x 10..13 od belki do podstawy
    for y in range(9, 39):
        put(10, y, OUTLINE); put(11, y, WOOD[1]); put(12, y, WOOD[2]); put(13, y, OUTLINE)
    # belka y 8..10 przez całą szerokość, czop na środku
    for x in range(1, 23):
        put(x, 7, OUTLINE); put(x, 8, WOOD[0]); put(x, 9, WOOD[2]); put(x, 10, OUTLINE)
    put(0, 8, OUTLINE); put(0, 9, OUTLINE); put(23, 8, OUTLINE); put(23, 9, OUTLINE)
    for x, y in ((11, 5), (12, 5), (10, 6), (13, 6)):
        put(x, y, OUTLINE)
    put(11, 6, METAL[0]); put(12, 6, METAL[1])
    # tarcza po lewej: okrąg r 4.6 pod belką, metalowy umbo
    cx, cy, r = 4.5, 15.0, 4.6
    for y in range(9, 21):
        for x in range(0, 10):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            if d <= r:
                c = OUTLINE if d > r - 1 else METAL[1] if d > r - 2 else WOOD[1] if x + 0.5 < cx else WOOD[2]
                put(x, y, c)
    put(4, 14, METAL[0]); put(5, 15, METAL[1]); put(4, 15, METAL[0]); put(5, 14, METAL[0])
    # worek po prawej: sznur z końca belki, worek y 15..23
    for y in range(11, 15):
        put(19, y, ROPE[0])
    bag = ['.AAAA.', 'AJJMKA', 'AJMMKA', 'AJMMKA', 'AMMKLA', 'AMKKLA', 'AKKLLA', '.AAAA.']
    pal = {'A': OUTLINE, 'J': JUTE[0], 'M': JUTE[1], 'K': JUTE[2], 'L': JUTE[3]}
    for j, row in enumerate(bag):
        for i, ch in enumerate(row):
            if ch != '.':
                put(17 + i, 15 + j, pal[ch])
    put(19, 15, ROPE[1]); put(20, 15, ROPE[1])
    return im


if __name__ == '__main__':
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else ''
    img, spin = build(), build_spin()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    spin.save(OUT_SPIN)
    print('->', OUT, OUT_SPIN, img.size)
    if preview:
        src = Image.open(SRC).convert('RGBA').crop(REGION)
        bg = Image.new('RGBA', (24 * 5, 47), (60, 90, 50, 255))
        bg.alpha_composite(src, (0, 0))
        bg.alpha_composite(img, (48, 0))
        bg.alpha_composite(spin, (96, 0))
        bg.resize((bg.width * 8, bg.height * 8), Image.NEAREST).save(preview)
