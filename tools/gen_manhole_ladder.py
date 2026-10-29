"""Drabina w perspektywie w otwartej studzience (Tiles.png ścieków, kafel 288,272 32x32).

Patrzymy z góry w szyb: drabina przy północnej ścianie schodzi w głąb, więc szyny zbiegają się ku środkowi,
szczeble są coraz krótsze, gęstsze i ciemniejsze (rampa miedzi drabiny z gen_ladder.py, wygaszana do czerni dziury).
Malujemy tylko po pikselach dziury (kolor HOLE), obręcz zostaje.
Użycie: python gen_manhole_ladder.py [--preview <plik.png>] [--dry]
"""
import os, sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
TILES = ROOT + 'assets/pixel_crawler/environments/sewer/Assets/Tiles.png'
TILE = (288, 272)
HOLE = (14, 17, 19)
## Jasna, średnia, ciemna miedź i najgłębszy cień (ten sam materiał co Ladder.png).
RAMP = [(219, 151, 126), (163, 95, 70), (106, 57, 39), (59, 35, 27)]
## Szyny: proste linie, od (TOP_Y, x LEFT / RIGHT) o 1 px ku środkowi co STEP wierszy, do BOTTOM_Y.
TOP_Y, BOTTOM_Y, STEP = 4, 19, 4
LEFT, RIGHT = 10, 22
## Szczeble: wiersze (co STEP, w połowie odcinka szyny) i odcień 0..3 — im głębiej, tym ciemniej.
RUNGS = [(6, 0), (10, 1), (14, 2), (18, 3)]


def rail_x(y: int) -> tuple:
    k = (y - TOP_Y) // STEP
    return LEFT + k, RIGHT - k


def paint(im: Image.Image) -> None:
    px = im.load()
    ox, oy = TILE

    def put(x, y, c):
        if px[ox + x, oy + y][:3] == HOLE:
            px[ox + x, oy + y] = c + (255,)

    # szyny: odcień wg szczebla poniżej (głębiej ciemniej)
    for y in range(TOP_Y, BOTTOM_Y + 1):
        shade = next((sh for ry, sh in RUNGS if ry >= y), RUNGS[-1][1])
        l, r = rail_x(y)
        put(l, y, RAMP[shade]); put(r, y, RAMP[shade])
    # szczeble między szynami; górny z ciemniejszym spodem
    for y, sh in RUNGS:
        l, r = rail_x(y)
        for x in range(l + 1, r):
            put(x, y, RAMP[sh])
            if sh == 0:
                put(x, y + 1, RAMP[2])


if __name__ == '__main__':
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else ''
    im = Image.open(TILES).convert('RGBA')
    before = im.crop((TILE[0], TILE[1], TILE[0] + 32, TILE[1] + 32))
    paint(im)
    after = im.crop((TILE[0], TILE[1], TILE[0] + 32, TILE[1] + 32))
    if '--dry' not in sys.argv:
        im.save(TILES)
        print('->', TILES)
    if preview:
        bg = Image.new('RGBA', (32 * 2 + 8, 32), (70, 60, 50, 255))
        bg.alpha_composite(before, (0, 0))
        bg.alpha_composite(after, (40, 0))
        bg.resize((bg.width * 10, bg.height * 10), Image.NEAREST).save(preview)
