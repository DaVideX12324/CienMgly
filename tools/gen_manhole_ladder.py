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
## Szczeble od góry: (y, lewa szyna x, prawa szyna x, odcień 0..3). Zbieżność ku środkowi kafla (x 15,5).
RUNGS = [(6, 11, 20, 0), (10, 12, 19, 1), (14, 13, 18, 2), (17, 14, 17, 3)]


def paint(im: Image.Image) -> None:
    px = im.load()
    ox, oy = TILE

    def put(x, y, c):
        if px[ox + x, oy + y][:3] == HOLE:
            px[ox + x, oy + y] = c + (255,)

    # szyny: odcinki między kolejnymi szczeblami, odcień jak niższy szczebel
    for (y0, l0, r0, _), (y1, l1, r1, s1) in zip(RUNGS, RUNGS[1:]):
        for y in range(y0, y1 + 1):
            t = (y - y0) / (y1 - y0)
            put(round(l0 + (l1 - l0) * t), y, RAMP[s1])
            put(round(r0 + (r1 - r0) * t), y, RAMP[s1])
    # szyny nad górnym szczeblem aż do obręczy
    l, r = RUNGS[0][1], RUNGS[0][2]
    for y in range(4, RUNGS[0][0]):
        put(l, y, RAMP[0]); put(r, y, RAMP[0])
    # szczeble (górny jaśniejszy z ciemniejszym spodem)
    for y, l, r, s in RUNGS:
        for x in range(l + 1, r):
            put(x, y, RAMP[s])
            if s == 0:
                put(x, y + 1, RAMP[s + 2])


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
