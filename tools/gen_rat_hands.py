"""Szczury Pixel Crawlera z rękami i bronią -> <Anim>-Hands-Sheet.png obok oryginalnych arkuszy (Idle, Run).

Ręce i broń z atlasu ściekowego „Poison Weapons” (assets/_nieuzywane/.../sewer/Weapons; ręce = prawy dolny róg).
Układ wzięty ze wzoru autora paczki (zrzut 4×: zwykły — zakrzywiony sztylet, łotrzyk — strzała + łuk, wojownik —
tarcza + włócznia, mag — mikstura + kostur): pozycje w klatce 64×64 dla klatki Idle 0, wszystko przed ciałem,
dłoń nad trzonkiem broni. W kolejnych klatkach warstwa idzie za ciałem: przesunięcie ciała względem Idle 0
(dopasowanie górnej części sylwetki), w pionie połowa bujania (ręce na wysokości pasa ruszają się mniej niż głowa).
Death bez rąk (oryginalny arkusz). SpriteFrames (resources/enemies/pixel_crawler/rat_*.tres) wskazują na *-Hands-Sheet.

Użycie: python gen_rat_hands.py [--preview]   (--preview: tylko podgląd 4× do %TEMP%/rat_hands_preview.png)
"""
import os, sys, tempfile
from PIL import Image
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
RATS = ROOT + 'assets/pixel_crawler/enemies/rat_enemy/'
ATLAS = ROOT + 'assets/_nieuzywane/pixel_crawler/environments/sewer/Weapons/Poison Weapons/Poison Weapons.png'
FRAME = 64
ANIMS = {'Idle': 4, 'Run': 6}

HAND = (116, 53, 8, 7)  # dłoń (prawy dolny róg atlasu); lustro = druga ręka
# (nazwa, wycinek atlasu x, y, w, h, odbicie w poziomie, pozycja w klatce Idle 0) — kolejność = kolejność rysowania
LAYOUT = {
    'Base': [
        ('dagger', (32, 16, 16, 32), True, (10, 27)),
        ('hand_back', HAND, False, (14, 50)),
        ('hand_front', HAND, True, (40, 53)),
    ],
    'Rogue': [
        ('arrow', (16, 0, 16, 16), False, (13, 45)),
        ('hand_back', HAND, False, (17, 50)),
        ('bow', (48, 48, 16, 32), False, (38, 32)),
        ('hand_front', HAND, True, (47, 47)),
    ],
    'Warrior': [
        ('shield', (112, 16, 28, 32), False, (1, 32)),
        ('spear', (66, 1, 12, 47), False, (43, 17)),
        ('hand_front', HAND, True, (45, 45)),
    ],
    'Mage': [
        ('flask', (80, 32, 16, 16), False, (14, 47)),
        ('hand_back', HAND, False, (18, 49)),
        ('staff', (96, 1, 16, 47), False, (42, 17)),
        ('hand_front', HAND, True, (46, 47)),
    ],
}
# Wycinki atlasu stykają się z sąsiednimi przedmiotami — bierzemy tylko spójną plamę najbliżej środka wycinka.
_atlas = Image.open(ATLAS).convert('RGBA')


def piece(rect, flip):
    from scipy import ndimage
    x, y, w, h = rect
    im = _atlas.crop((x, y, x + w, y + h))
    a = np.asarray(im).copy()
    lab, n = ndimage.label(a[:, :, 3] > 0, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = 1 + int(np.argmax(sizes))
        a[lab != keep] = 0
    im = Image.fromarray(a)
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def body_shift(base0, frame):
    """(dx, dy) ciała klatki względem Idle 0 — najlepsze pokrycie górnej części sylwetki (wiersze < 52)."""
    best = (-1.0, 0, 0)
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            shifted = np.zeros_like(base0)
            ys, yd = slice(max(0, dy), min(FRAME, FRAME + dy)), slice(max(0, -dy), min(FRAME, FRAME - dy))
            xs, xd = slice(max(0, dx), min(FRAME, FRAME + dx)), slice(max(0, -dx), min(FRAME, FRAME - dx))
            shifted[ys, xs] = base0[yd, xd]
            a, b = shifted[:52], frame[:52]
            m = (a[:, :, 3] > 0) | (b[:, :, 3] > 0)
            score = ((np.abs(a - b).sum(axis=2) < 8) & m).sum() / max(m.sum(), 1)
            if score > best[0]:
                best = (score, dx, dy)
    return best[1], best[2]


def build(kind):
    layers = [(piece(rect, flip), pos) for _, rect, flip, pos in LAYOUT[kind]]
    base0 = np.asarray(Image.open(RATS + f'Rat - {kind}/Idle/Idle-Sheet.png').convert('RGBA'), dtype=int)[:, :FRAME]
    out = {}
    for anim, count in ANIMS.items():
        sheet = Image.open(RATS + f'Rat - {kind}/{anim}/{anim}-Sheet.png').convert('RGBA')
        res = sheet.copy()
        for f in range(count):
            fr = np.asarray(sheet.crop((f * FRAME, 0, (f + 1) * FRAME, FRAME)), dtype=int)
            dx, dy = body_shift(base0, fr)
            dy = int(np.sign(dy)) * ((abs(dy) + 1) // 2)  # pół bujania w pionie
            cell = sheet.crop((f * FRAME, 0, (f + 1) * FRAME, FRAME))
            for im, (px, py) in layers:
                cell.alpha_composite(im, (px + dx, py + dy))
            res.paste(cell, (f * FRAME, 0))
        out[anim] = res
    return out


def main():
    preview = '--preview' in sys.argv
    sheets = {kind: build(kind) for kind in LAYOUT}
    if preview:
        rows = [s for kind in LAYOUT for s in sheets[kind].values()]
        w, h = max(r.width for r in rows), sum(r.height for r in rows)
        img = Image.new('RGBA', (w, h), (40, 40, 46, 255))
        y = 0
        for r in rows:
            img.alpha_composite(r, (0, y))
            y += r.height
        path = os.path.join(tempfile.gettempdir(), 'rat_hands_preview.png')
        img.resize((w * 4, h * 4), Image.NEAREST).save(path)
        print(path)
        return
    for kind, anims in sheets.items():
        for anim, img in anims.items():
            path = RATS + f'Rat - {kind}/{anim}/{anim}-Hands-Sheet.png'
            img.save(path)
            print(os.path.relpath(path, ROOT))


if __name__ == '__main__':
    main()
